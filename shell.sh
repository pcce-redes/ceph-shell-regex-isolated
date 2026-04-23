#!/usr/bin/env bash
set -Eeuo pipefail

TARGETS=(/etc /opt /root /home /usr/local /var)
BACKUP_EXT=".bak"

echo "[INFO] Procurando arquivos texto com 10.10.111.* ..."
sudo find "${TARGETS[@]}" -type f \
  ! -path "/var/log/*" \
  -exec grep -Il '10\.10\.111\.' {} \; |
while IFS= read -r file; do
  echo "[INFO] Alterando: $file"
  sudo sed -E -i"${BACKUP_EXT}" \
    -e 's#10\.10\.111\.([0-9]{1,3})/25#10.10.120.\1/25#g' \
    -e 's#10\.10\.111\.([0-9]{1,3})#10.10.120.\1#g' \
    "$file"
done

echo "[OK] Concluído."
echo "[OK] Backups salvos com extensão ${BACKUP_EXT}"
