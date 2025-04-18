# Lab Configurations
initials      = "bmm"
random_string = "udtyw4"

## Tag Vars
tags = {
  "Owner"       = "BMM"
  "Environment" = "GitOps Lab"
}

## App Server Confiugurations
appServersConfig = {
    vmnameprefix    = "webapp"
    vmcount         = 2
    adminUsername   = "labAdmin"
    zones           = ["3"]
    key_path        = "/home/vscode/.ssh/docker.pub"
    vm_sku          = "Standard_D2s_v6"
}