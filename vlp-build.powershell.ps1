#Variables

$VLPHOME="$HOME\.vpn-launchpad"
$RESOURCE="vpngroup"
$VM="vpnserver"
$REGION="westus2"
$sshpub="$VLPHOME\id_rsa.pub"
$sshkey="id_rsa"
$AzureCLI="C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\wbin\az.cmd"
$VMNETWORK="vpnnet"
$subscription = "KPMGAU-BUS-INN-INFOSEC"
$regx="([0-9]{1,3}[\.]){3}[0-9]{1,3}"
$admin="vpnuser"
$password="VPNserver1@!2"

#Credential
$secstr = New-Object -TypeName System.Security.SecureString
$password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $admin, $secstr
$computername = "52.183.97.155"


write-host "Checking for azure installation"
if ( !(Test-Path -path $AzureCLI) ){
write-host "Please install Azure CLI tool from Microsoft"
}
else{
Write-host "Continue ...."
}

#Generating ssh key
Write-Host " Creating Key-Pair of $VM..." 
if ( ! (Test-path -path $VLPHOME)){
mkdir $VLPHOME
}
else{
.\ssh-keygen.exe -f $VLPHOME\.ssh\id_rsa -t rsa -b 2048 -N 'vpnpass'
}

write-host "Set subscription"
az account set --subscription $subscription

write-host "Creating resource group $RESOURCE....."
az group create -n $RESOURCE -l $REGION

#Creating virtual machine
echo "Creating instance of $VM....."

#az vm create -n $VM -g $RESOURCE --image UbuntuLTS --data-disk-sizes-gb 10 --ssh-key-value $sshpub --generate-ssh-keys
az vm create -n $VM -g $RESOURCE --image UbuntuLTS --data-disk-sizes-gb 10 --admin-user $admin --admin-password $password

az network public-ip list -g $RESOURCE > $VLPHOME\ip.txt
$IPPUB=Get-Content $VLPHOME\ip.txt | select-string -Pattern $regx -AllMatches | % { $_.Matches } | % { $_.Value }
write-host "You Public IP address is $IPPUB"

write-host " Creating Firewall rules"
az network nsg rule create --resource-group $RESOURCE --nsg-name $VM"NSG" --name Rule1 --protocol udp --priority 100 --destination-port-range 500
az network nsg rule create --resource-group $RESOURCE --nsg-name $VM"NSG" --name Rule2 --protocol udp --priority 101 --destination-port-range 4500
az network nsg rule create --resource-group $RESOURCE --nsg-name $VM"NSG" --name Rule3 --protocol tcp --priority 102 --destination-port-range 1701
az network nsg rule create --resource-group $RESOURCE --nsg-name $VM"NSG" --name Rule4 --protocol udp --priority 103 --destination-port-range 1194
az network nsg rule create --resource-group $RESOURCE --nsg-name $VM"NSG" --name Rule5 --protocol tcp --priority 104 --destination-port-range 555
az network nsg rule create --resource-group $RESOURCE --nsg-name $VM"NSG" --name Rule6 --protocol udp --priority 105 --destination-port-range 8388
az network nsg rule create --resource-group $RESOURCE --nsg-name $VM"NSG" --name Rule7 --protocol tcp --priority 106 --destination-port-range 8388
az network vnet subnet update --resource-group $RESOURCE --vnet-name $VM"VNET" --name $VM"Subnet" --network-security-group $VM"NSG"

write-host "Instance Provisioning"
Remove-SSHSession -SessionId 0,1,2,3,4,5
$sessionid= "New-SSHSession -computername= $computername -credential $cred | % {$_.sessionaid}
.\plink.exe -pw $password $admin@$IPPUB "sudo apt-get -y update; sudo apt-get install -y docker.io docker-compose python-pip git"
.\plink.exe -pw $password $admin@$IPPUB "sudo sh -c \"echo '\n\nnet.core.default_qdisc=fq'>>/etc/sysctl.conf\""
.\plink.exe -pw $password $admin@$IPPUB "sudo sh -c \"echo '\nnet.ipv4.tcp_congestion_control=bbr'>>/etc/sysctl.conf\""
.\plink.exe -pw $password $admin@$IPPUB "sudo sysctl -p"
.\plink.exe -pw $password $admin@$IPPUB "sudo usermod -aG docker $admin"

<#write-host "L2TP Provisioning"
.\pscp.exe -i $VLPHOME/$sshkey -r $DIR/docker-sevpn $USER@$IPPUB:
.\plink.exe ssh -i $VLPHOME/$sshkey $USER@$IPPUB "cd docker-sevpn; sh sevpn.sh"

write-host " Shadowsocks-libev provisioning ...."
.\pscp.exe -i $VLPHOME/$sshkey -r $DIR/docker-shadowsocks-libev $USER@$IPPUB:

.\plink.exe -i $VLPHOME/$sshkey $USER@$IPPUB "cd docker-shadowsocks-libev; sh shadowsocks-libev.sh"#>
