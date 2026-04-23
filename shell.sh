sudo find / -type f \
  ! -path "/proc/*" ! -path "/sys/*" ! -path "/dev/*" ! -path "/run/*" \
  ! -path "/snap/*" ! -path "/tmp/*" ! -path "/var/lib/docker/*" \
  -exec grep -Il '10\.10\.111\.' {} \; \
  -exec sed -E -i.bak \
    's#10\.10\.111\.([0-9]{1,3})/25#10.10.120.\1/25#g; s#10\.10\.111\.([0-9]{1,3})#10.10.120.\1#g' {} +