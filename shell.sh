#!/usr/bin/env bash
set -Eeuo pipefail

TARGETS=(/etc /opt /root /home /usr/local /var)
BACKUP_EXT=".bak"
HOSTNAME_FQDN="$(hostname -f 2>/dev/null || hostname)"
HOSTNAME_SHORT="$(hostname -s 2>/dev/null || hostname)"

echo "[INFO] Host detectado: ${HOSTNAME_FQDN}"

echo "[INFO] Validando se o host pode entrar em manutenção no Ceph..."
if sudo ceph orch host ok-to-stop "${HOSTNAME_FQDN}" >/dev/null 2>&1; then
  CEPH_HOST="${HOSTNAME_FQDN}"
elif sudo ceph orch host ok-to-stop "${HOSTNAME_SHORT}" >/dev/null 2>&1; then
  CEPH_HOST="${HOSTNAME_SHORT}"
else
  echo "[ERRO] Não foi possível validar o host no Ceph com hostname -f nem hostname -s."
  echo "[ERRO] Confira o nome exato em: ceph orch host ls"
  exit 1
fi

echo "[INFO] Host no Ceph: ${CEPH_HOST}"
echo "[INFO] Checando segurança para parada..."
sudo ceph orch host ok-to-stop "${CEPH_HOST}"

echo "[INFO] Colocando host em manutenção no Ceph..."
sudo ceph orch host maintenance enter "${CEPH_HOST}" --yes-i-really-mean-it

echo "[INFO] Garantindo parada local dos serviços Ceph..."
sudo systemctl stop ceph.target || true

echo "[INFO] Iniciando varredura..."

checked=0
matched=0
changed=0

for dir in "${TARGETS[@]}"; do
  echo "[INFO] Verificando diretório: $dir"

  sudo find "$dir" -type f \
    ! -path "/var/log/*" 2>/dev/null |
  while IFS= read -r file; do
    checked=$((checked + 1))
    echo "[CHECK] Checando arquivo: $file"

    if sudo grep -Iq . "$file" 2>/dev/null && sudo grep -qE '10\.10\.111\.' "$file" 2>/dev/null; then
      matched=$((matched + 1))
      echo "[MATCH] Encontrado padrão em: $file"

      before_hash="$(sudo sha256sum "$file" | awk '{print $1}')"

      sudo sed -E -i"${BACKUP_EXT}" \
        -e 's#10\.10\.111\.([0-9]{1,3})/25#10.10.120.\1/25#g' \
        -e 's#10\.10\.111\.([0-9]{1,3})#10.10.120.\1#g' \
        "$file"

      after_hash="$(sudo sha256sum "$file" | awk '{print $1}')"

      if [[ "$before_hash" != "$after_hash" ]]; then
        changed=$((changed + 1))
        echo "[EDIT] Alterado: $file"
      else
        echo "[SKIP] Sem alteração efetiva: $file"
      fi
    fi
  done
done

echo "[OK] Concluído."
echo "[OK] Arquivos checados : $checked"
echo "[OK] Arquivos com match: $matched"
echo "[OK] Arquivos alterados: $changed"
echo "[OK] Backups salvos com extensão ${BACKUP_EXT}"

echo
echo "[INFO] Quando terminar a manutenção e quiser subir o host novamente:"
echo "sudo ceph orch host maintenance exit ${CEPH_HOST}"
echo "sudo systemctl start ceph.target"
