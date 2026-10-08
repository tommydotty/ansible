#!/bin/bash
set -euo pipefail

INPUT_FILE="/home/B0N4022/.ansible/clusters.json"
OUTPUT_FILE="/home/B0N4022/.ansible/inventory/kubevirt.json"

command -v jq >/dev/null 2>&1 || {
  echo "❌ jq non trovato. Installalo con: yum install jq -y"
    exit 1
  }

  # JSON in memoria
  INVENTORY="{ }"

  # Aggiunge un gruppo se non esiste
  add_group() {
      group="$1"
        INVENTORY=$(jq --arg g "$group" '
            .[$g] //= { "hosts": {}, "children": {}, "vars": {} }
              ' <<< "$INVENTORY")
            }

            # Aggiunge un host a un gruppo
            add_host() {
                group="$1"
                  host="$2"
                    INVENTORY=$(jq --arg g "$group" --arg h "$host" '
                        .[$g].hosts[$h] = {}
                          ' <<< "$INVENTORY")
                        }

                        # Aggiunge un child a un gruppo
                        add_child() {
                            parent="$1"
                              child="$2"
                                INVENTORY=$(jq --arg p "$parent" --arg c "$child" '
                                    .[$p].children[$c] = {}
                                      ' <<< "$INVENTORY")
                                    }

                                    # Parsing cluster
                                    while read -r cluster; do
                                        name=$(jq -r '.name' <<< "$cluster")
                                          env=$(jq -r '.env' <<< "$cluster")
                                            layer=$(jq -r '.layer' <<< "$cluster")

                                              # Gruppi
                                                add_group "clusters"
                                                  add_group "$env"
                                                    add_group "$layer"
                                                      add_group "${layer}_${env}"
                                                        add_group "$name"     # <- qui HOGLIERE LE VM

                                                          # Collegamenti gerarchici
                                                            add_child "clusters" "$env"
                                                              add_child "$env" "${layer}_${env}"
                                                                add_child "$layer" "${layer}_${env}"

                                                                  # IL CAMBIO RICHIESTO:
                                                                    # invece di: add_host "${layer}_${env}" "$vm"
                                                                      # ora:      add_host "$name" "$vm"

                                                                        # VM del cluster
                                                                          vmlist=$(dmtcon -N "$name" -r m1 -c \
                                                                                "dlogin > /dev/null ; kubectl get vm -A --no-headers | awk '{print \$2}'" < /dev/null \
                                                                                    | grep -v Eseguo || true)

                                                                            while read -r vm; do
                                                                                  [[ -n "$vm" ]] && add_host "$name" "$vm"
                                                                                    done <<< "$vmlist"

                                                                                      # Infine: collega il cluster al gruppo layer_env
                                                                                        add_child "${layer}_${env}" "$name"

                                                                                      done < <(jq -c '.clusters[]' "$INPUT_FILE")

                                                                                      echo "$INVENTORY" | jq '.' > "$OUTPUT_FILE"

                                                                                      echo "✔️ Inventory JSON generato: $OUTPUT_FILE"

