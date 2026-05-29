include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path = "${get_repo_root()}/infra/live/_envcommon/network.hcl"
}

terraform {
  source = "${get_repo_root()}/infra/modules/network"
}
