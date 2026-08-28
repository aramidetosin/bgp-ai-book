import pandas as pd
from pybatfish.client.session import Session
pd.set_option("display.width", 200); pd.set_option("display.max_colwidth", 30)
bf = Session(host="localhost"); bf.set_network("bgpbook")
bf.init_snapshot("snapshot", name="twin", overwrite=True)
ps = bf.q.fileParseStatus().answer().frame()
print("=== the twin parses as Cumulus, every device a node ===")
print(ps[["File_Name", "Status", "File_Format"]].to_string(index=False))
st = bf.q.bgpSessionStatus().answer().frame()
print("\n=== every eBGP session the twin would establish ===")
print(st[["Node", "Local_Interface", "Remote_Node", "Established_Status"]].to_string(index=False))
print(f"\ntotal: {len(st)} sessions, all {st['Established_Status'].unique().tolist()}")
