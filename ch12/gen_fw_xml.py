#!/usr/bin/env python3
"""Chapter 12: generate the firewall pair's configuration XML.

One template, two devices: fw-a (priority 100, preemptive) and fw-b
(priority 200). The launcher merges the tree into the candidate config
section by section and commits; identical zones, interfaces, routes,
NAT, and security policy on both is exactly what an active/passive pair
wants, and generating both from one function is how the lab keeps them
identical.
"""
import os

TEMPLATE = """<config version="12.1.0" urldb="paloaltonetworks" detail-version="12.1.2">
  <devices>
    <entry name="localhost.localdomain">
      <network>
        <interface>
          <ethernet>
            <entry name="ethernet1/1">
              <layer3>
                <ip>
                  <entry name="172.31.1.1/31" />
                </ip>
                <mtu>1500</mtu>
              </layer3>
            </entry>
            <entry name="ethernet1/2">
              <layer3>
                <ip>
                  <entry name="203.0.113.0/31" />
                </ip>
                <mtu>1500</mtu>
              </layer3>
            </entry>
            <entry name="ethernet1/3">
              <ha />
            </entry>
            <entry name="ethernet1/4">
              <ha />
            </entry>
          </ethernet>
        </interface>
        <virtual-router>
          <entry name="default">
            <interface>
              <member>ethernet1/1</member>
              <member>ethernet1/2</member>
            </interface>
            <routing-table>
              <ip>
                <static-route>
                  <entry name="default-to-provider">
                    <destination>0.0.0.0/0</destination>
                    <interface>ethernet1/2</interface>
                    <nexthop>
                      <ip-address>203.0.113.1</ip-address>
                    </nexthop>
                  </entry>
                  <entry name="fabric-servers">
                    <destination>172.16.0.0/16</destination>
                    <interface>ethernet1/1</interface>
                    <nexthop>
                      <ip-address>172.31.1.0</ip-address>
                    </nexthop>
                  </entry>
                  <entry name="fabric-loopbacks">
                    <destination>10.0.0.0/24</destination>
                    <interface>ethernet1/1</interface>
                    <nexthop>
                      <ip-address>172.31.1.0</ip-address>
                    </nexthop>
                  </entry>
                </static-route>
              </ip>
            </routing-table>
          </entry>
        </virtual-router>
      </network>
      <deviceconfig>
        <system>
          <hostname>{hostname}</hostname>
          <timezone>UTC</timezone>
        </system>
        <high-availability>
          <enabled>yes</enabled>
          <interface>
            <ha1>
              <port>ethernet1/3</port>
              <ip-address>{ha1_ip}</ip-address>
              <netmask>255.255.255.0</netmask>
            </ha1>
            <ha2>
              <port>ethernet1/4</port>
              <ip-address>{ha2_ip}</ip-address>
              <netmask>255.255.255.0</netmask>
            </ha2>
          </interface>
          <group>
            <group-id>1</group-id>
            <description>chapter 12 edge pair</description>
            <peer-ip>{peer_ha1_ip}</peer-ip>
            <mode>
              <active-passive>
                <passive-link-state>auto</passive-link-state>
              </active-passive>
            </mode>
            <election-option>
              <device-priority>{priority}</device-priority>
              {preempt}
            </election-option>
            <state-synchronization>
              <enabled>yes</enabled>
            </state-synchronization>
          </group>
        </high-availability>
      </deviceconfig>
      <vsys>
        <entry name="vsys1">
          <import>
            <network>
              <interface>
                <member>ethernet1/1</member>
                <member>ethernet1/2</member>
              </interface>
            </network>
          </import>
          <zone>
            <entry name="trust">
              <network>
                <layer3>
                  <member>ethernet1/1</member>
                </layer3>
              </network>
            </entry>
            <entry name="untrust">
              <network>
                <layer3>
                  <member>ethernet1/2</member>
                </layer3>
              </network>
            </entry>
          </zone>
          <service>
            <entry name="tcp-80">
              <protocol>
                <tcp>
                  <port>80</port>
                </tcp>
              </protocol>
            </entry>
          </service>
          <rulebase>
            <security>
              <rules>
                <entry name="inbound-public-web">
                  <from>
                    <member>untrust</member>
                  </from>
                  <to>
                    <member>trust</member>
                  </to>
                  <source>
                    <member>any</member>
                  </source>
                  <destination>
                    <member>203.0.113.100</member>
                  </destination>
                  <application>
                    <member>any</member>
                  </application>
                  <service>
                    <member>tcp-80</member>
                  </service>
                  <action>allow</action>
                  <log-end>yes</log-end>
                </entry>
                <entry name="outbound-cluster">
                  <from>
                    <member>trust</member>
                  </from>
                  <to>
                    <member>untrust</member>
                  </to>
                  <source>
                    <member>any</member>
                  </source>
                  <destination>
                    <member>any</member>
                  </destination>
                  <application>
                    <member>any</member>
                  </application>
                  <service>
                    <member>any</member>
                  </service>
                  <action>allow</action>
                  <log-end>yes</log-end>
                </entry>
              </rules>
            </security>
            <nat>
              <rules>
                <entry name="no-nat-edge-bgp">
                  <from>
                    <member>trust</member>
                  </from>
                  <to>
                    <member>untrust</member>
                  </to>
                  <source>
                    <member>172.31.1.0/31</member>
                  </source>
                  <destination>
                    <member>203.0.113.1</member>
                  </destination>
                  <service>any</service>
                </entry>
                <entry name="dnat-public-vip">
                  <from>
                    <member>untrust</member>
                  </from>
                  <to>
                    <member>untrust</member>
                  </to>
                  <source>
                    <member>any</member>
                  </source>
                  <destination>
                    <member>203.0.113.100</member>
                  </destination>
                  <service>tcp-80</service>
                  <destination-translation>
                    <translated-address>172.16.200.1</translated-address>
                  </destination-translation>
                </entry>
                <entry name="snat-cluster-out">
                  <from>
                    <member>trust</member>
                  </from>
                  <to>
                    <member>untrust</member>
                  </to>
                  <source>
                    <member>any</member>
                  </source>
                  <destination>
                    <member>any</member>
                  </destination>
                  <service>any</service>
                  <source-translation>
                    <dynamic-ip-and-port>
                      <interface-address>
                        <interface>ethernet1/2</interface>
                      </interface-address>
                    </dynamic-ip-and-port>
                  </source-translation>
                </entry>
              </rules>
            </nat>
          </rulebase>
        </entry>
      </vsys>
    </entry>
  </devices>
</config>
"""

DEVICES = {
    "fw-a": dict(hostname="fw-a", ha1_ip="169.254.1.1", ha2_ip="169.254.2.1",
                 peer_ha1_ip="169.254.1.2", priority=100,
                 preempt="<preemptive>yes</preemptive>"),
    "fw-b": dict(hostname="fw-b", ha1_ip="169.254.1.2", ha2_ip="169.254.2.2",
                 peer_ha1_ip="169.254.1.1", priority=200,
                 preempt=""),
}

os.makedirs("bootstrap", exist_ok=True)
for name, vals in DEVICES.items():
    open(f"bootstrap/{name}.xml", "w").write(TEMPLATE.format(**vals))
    print(f"wrote bootstrap/{name}.xml")
