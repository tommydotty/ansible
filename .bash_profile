# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

unset TMOUT

# User specific environment and startup programs

#Create login report
dlogin &>/dev/null
echo
echo "  ----------------------------------------------"
echo "  System report for cluster : $(dctl cluster status | awk '/Name/{print $3; exit}')"
echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  ----------------------------------------------"
echo
echo "=================================================================================================================================================="
echo "Cluster Status :"

out=$(dctl cluster status | awk '/^NAME/{flag=1} flag' | column -t)
if [ -n "$out" ]; then
  echo "$out" | sed 's/^/  /'
else
  echo "NONE"
fi

out=$(dctl drive list)

if [ -z "$out" ]; then
  echo "Drives not Up:"
  echo "NONE"
  echo
  return 0 2>/dev/null || exit 0
fi

# 1) Drives not Up (stampa NODE,SLOT,S/N,DRIVESET)
non_up=$(printf "%s\n" "$out" | awk '
BEGIN { FS = "[[:space:]]{2,}" }
NR==1 {
  for(i=1;i<=NF;i++){
    if($i ~ /^SLOT$/) slot=i
    if($i ~ /^S\/N$/) sn=i
    if($i ~ /^DRIVESET$/) ds=i
    if($i ~ /^STATE$/) st=i
  }
  next
}
NR>1 {
  state = (st ? $(st) : "")
  if(state != "Up") {
    print $1, (slot?$(slot):""), (sn?$(sn):""), (ds?$(ds):"")
  }
}
')

echo "Drives not Up:"
if [ -n "$non_up" ]; then
  echo "$non_up" | column -t | sed 's/^/  /'
else
  echo "NONE"
fi

echo
echo "Nodes with storage >90% allocated:"
dctl cluster status | awk '
  BEGIN { found=0 }
  BEGIN { found=0 }
  NR>8 {
  # Salta le prime 8 righe (header e info del cluster)
  gsub(/[M,G,T,P]B/, "", $7)
  split($7, a, "/")
  used = a[1]
  total = a[2]
  percent = (total>0) ? used/total*100 : 0
  if (percent > 90) {
    printf "WARNING: %-50s utilizza il %.2f%% dello storage totale\n", $1, percent
    found=1
    }
}
END {
  if (found == 0)
    print "NONE"
}'
       

echo
echo "Volume with problems"
out=$(dctl volume list | egrep -v 'Attached|Available|NAME' | awk '{print $1}')
if [ -n "$out" ]; then
  echo "$out" | sed 's/^/  /'
else
  echo "NONE"
fi

echo
echo "System POD failed:"
out=$(kubectl get pod -A -o json   | jq -r '.items[] | select(.status.phase != "Running") | "\(.metadata.namespace)\t\(.metadata.name)"')
if [ -n "$out" ]; then
  printf "NAMESPACE\t\t\tNAME\n"
  echo "$out" | sed 's/^/  /'
else
  echo "NONE"
fi

echo
echo "VM not running:"
out=$(kubectl get vm -A -o json   | jq -r '.items[] | select(.status.printableStatus != "Running") | "\(.metadata.name)"')
if [ -n "$out" ]; then
  echo "$out" | sed 's/^/  /'
else
  echo "NONE"
fi

echo
echo "Trap SNMP ERROR"
out=$(dctl event list  --sev ERROR | grep -Ev '^[0-9]+d')
if [[ $(dctl event list  --sev ERROR | grep -Ev '^[0-9]+d' | wc -l) > 1 ]]; then
  echo "$out" | sed 's/^/  /'
else
  echo "NONE"
fi

echo "=================================================================================================================================================="
echo ""
