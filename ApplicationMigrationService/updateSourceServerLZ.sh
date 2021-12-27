##################################################################
#                           Info
##################################################################

# Author: Eric Lee
# Created Date: 2021/12/23
# https://veric.me
# https://github.com/tigerhawk6/AWS



##################################################################
#                           Prereq's
##################################################################

#   Latest eddition of AWS CLI Version 2
#   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

#   Configure AWS CLI with token ID, Token, default region as region replicating to. Leave ouput as defualt (json)
#   https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html

#   JQ installed and in environment path
#   https://stedolan.github.io/jq/download/


##################################################################
#                   User Definable Parameters
##################################################################

#   Start with the Source ID for the server wanting to upate. 
#   Get this from output of agent install OR MGN console
#   Format is s-xxxxxxxxxxxxxxxxx
sourceID=''

#   Instance Type
#   KC LZ Available Options - aws ec2 describe-instance-type-offerings --location-type availability-zone --filters Name=location,Values=us-east-1-mci-1a --region us-east-1
insType='t3.xlarge'

#   Subnet to connect Instance NIC to (subnet-xxxxxxxxxxxxxx)
nicSubnetID=''

#   Security Groups to applyu to Instance NIC (sg-xxxxxxxxxxxxxxxxx)
nicSecGroup=''



##################################################################
#          Create new launch template for source server
##################################################################

#   Update Instance Type Right Sizing parameter of Launch Template
aws mgn update-launch-configuration --source-server-id $sourceID --target-instance-type-right-sizing-method NONE

#   Get Launch Template ID and set to variable
sourceIDlaunchTemplate=$(aws mgn get-launch-configuration --source-server-id $sourceID | jq '.ec2LaunchTemplateID' | sed 's/"//g')

#   Get disk info for source server
#   Update disk to GP2
#   Set EC2 instance to type per variable above
#   Set Network subnet and security groups per variables above

NEW_LAUNCH_TEMPLATE_VESRSION_DATA=$(aws ec2 describe-launch-template-versions --versions 2 --launch-template-id $sourceIDlaunchTemplate --no-cli-pager | \
jq '.LaunchTemplateVersions[0].LaunchTemplateData' | \
jq  'del( .TagSpecifications, .BlockDeviceMappings[].Ebs.Iops)' | \
jq '(.BlockDeviceMappings[].Ebs.VolumeType) |= "gp2"' | \
jq --arg instantype "$insType" '(.InstanceType) |= $instantype' | \
jq --arg nicSubnet "$nicSubnetID" --arg nicSec "$nicSecGroup" '.NetworkInterfaces[0] += {"SubnetId": $nicSubnet, "Groups": [$nicSec]}' | \
jq '. + {"EbsOptimized": false}')


#   Create new Launch Template version
aws ec2 create-launch-template-version --launch-template-id $sourceIDlaunchTemplate --version-description KCLocalZoneDeployment --source-version 2 --launch-template-data "$NEW_LAUNCH_TEMPLATE_VESRSION_DATA"

#   Set new Launch Template version as default
NEW_LAUNCH_TEMPLATE_VERSION=$(aws ec2 describe-launch-template-versions --versions $Latest --launch-template-id $sourceIDlaunchTemplate --no-cli-pager | jq '.LaunchTemplateVersions[0].VersionNumber')
aws ec2 modify-launch-template --launch-template-id $sourceIDlaunchTemplate --default-version $NEW_LAUNCH_TEMPLATE_VERSION

