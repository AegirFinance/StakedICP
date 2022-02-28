#!/bin/bash -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$DIR"/../../../ic/rs

protoc \
  -I nns/governance/proto \
  -I nns/common/proto \
  -I types/base_types/proto \
  -I rosetta-api/ledger_canister/proto \
  nns/governance/proto/ic_nns_governance/pb/v1/governance.proto \
  --encode ic_nns_governance.pb.v1.Governance \
  < "$DIR/initial-governance.textproto" \
  > "$DIR/initial-governance.pb"

<"$DIR/initial-governance.pb" od -A n -v -t x1 | tr -d ' \n' >"$DIR/initial-governance.hex" 
