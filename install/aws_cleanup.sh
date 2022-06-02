#!/bin/bash

set -x

path=$(dirname $0) 
clusterId=${1}


#
# CLI for AWS
#
function install_aws_cli() {
    local result=0

    # https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
    local aws_dir="${WORKDIR}/aws_cli"
    echo "INFO: Checking AWS client installation..." 
    aws --version > /dev/null 2>&1 || result=1
    if [ ${result} -eq 0 ]; then
        aws_cmd=$(type -p aws)
    else
        local unpack_dir="${WORKDIR}"
        curl -sL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "${unpack_dir}/awscliv2.zip" \
        && unzip -qq "${unpack_dir}/awscliv2.zip" -d "${unpack_dir}" \
        && "${unpack_dir}/aws/install" -i ${aws_dir} -b ${aws_dir} \
        && aws_cmd="${aws_dir}/aws" \
        && result=0 \
        || result=1
    fi

    if [ ${result} -eq 0 ]; then
        echo "INFO: Installed AWS CLI."
    else
        echo "ERROR: AWS CLI installation failed."
    fi

    return ${result}
}


if [ -z "$clusterId" ]; then
  exit 
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  exit 80
fi
if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  exit 80
fi
if [ -z "$AWS_DEFAULT_REGION" ]; then
  exit 80
fi

WORKDIR=/tmp \
&& install_aws_cli \
|| exit 1

echo "0 - Start processing for cluster $clusterId - waiting for masters to be destroyed"
masters=3
while [ $masters -gt 0 ]; do
  nodes=$(${aws_cmd} ec2 describe-instances --filters Name="tag:kubernetes.io/cluster/${clusterId}",Values="owned"  Name="instance-state-name",Values="running" --query 'Reservations[].Instances[].[InstanceId, Tags[?Key==`Name`] | [0].Value]' --output text)
  masters=$(echo "$nodes" | grep master | wc -l) 
  echo "Waiting for masters to be destroyed - $masters remaining"
  if [ $masters -gt 0 ]; then
    sleep 10
  fi
done

workers=$(echo "$nodes" | cut -d$'\t' -f1)
echo "1 - Deleting workers - $workers -"
if [ -n "$workers" ]; then 
  ${aws_cmd} ec2 terminate-instances --instance-ids ${workers} 
fi
vpcid=$(${aws_cmd} ec2 describe-vpcs --filters Name="tag:kubernetes.io/cluster/${clusterId}",Values="owned" --query 'Vpcs[].VpcId' --output text)
if [ -n "$vpcid" ]; then
  elbname=$(${aws_cmd} elb describe-load-balancers --query  'LoadBalancerDescriptions[].[LoadBalancerName,VPCId]' --output text | grep $vpcid | cut -d$'\t' -f1)
  echo "2 - Deleting apps load balancers - $elbname - "
  if [ -n "$elbname" ]; then 
    ${aws_cmd} elb delete-load-balancer --load-balancer-name ${elbname}
  fi
  sleep 30
fi

sg=$(${aws_cmd} ec2 describe-security-groups --filters Name="tag:kubernetes.io/cluster/${clusterId}",Values="owned" --query 'SecurityGroups[].[GroupId,GroupName]' --output text | grep "k8s-elb" | cut -d$'\t' -f1)

echo "3 - Deleting elb security group - $sg -"
while [ -n "$sg" ]; do
  ${aws_cmd} ec2 delete-security-group --group-id ${sg}
  sleep 10
  sg=$(${aws_cmd} ec2 describe-security-groups --filters Name="tag:kubernetes.io/cluster/${clusterId}",Values="owned" --query 'SecurityGroups[].[GroupId,GroupName]' --output text | grep "k8s-elb" | cut -d$'\t' -f1)
done

s3imagereg=$(${aws_cmd} s3 ls | grep ${clusterId} | awk '{print $3}') 
echo "4 - Deleting S3 image-registry $s3imagereg -"
if [ -n "$s3imagereg" ]; then
  ${aws_cmd} s3 rb --force s3://$s3imagereg
fi
echo "5 - Deleting iamusers - $iamusers"
while read iamuser; do
  ${aws_cmd} iam delete-user-policy --user-name "$iamuser" --policy-name "$iamuser-policy"
  ${aws_cmd} iam delete-access-key --user-name "$iamuser" --access-key-id $(${aws_cmd} iam list-access-keys --user-name "$iamuser" --query 'AccessKeyMetadata[].AccessKeyId' --output text)
  ${aws_cmd} iam delete-user --user-name "$iamuser"
done <<< "$(${aws_cmd} iam list-users --query 'Users[].[UserName,UserId]' --output text | grep ${clusterId} | cut -f 1)"

vpc_endpoints=$(${aws_cmd} ec2 describe-vpc-endpoints --region ${AWS_DEFAULT_REGION} --filters Name="tag:kubernetes.io/cluster/${clusterId}",Values="owned" --query 'VpcEndpoints[].VpcEndpointId' --output text)
echo "6 - Deleting vpc_endpoints - $vpc_endpoints"
if [ -n "$vpc_endpoints" ]; then
  ${aws_cmd} ec2 delete-vpc-endpoints --region ${AWS_DEFAULT_REGION} --vpc-endpoint-ids ${vpc_endpoints}
fi

nat_gateways=$(${aws_cmd} ec2 describe-nat-gateways --region ${AWS_DEFAULT_REGION} | jq -r --arg infra_id ${clusterId} ".NatGateways[] | select(.Tags[].Key==\"kubernetes.io/cluster/$clusterId\").NatGatewayId")
echo "7 - Deleting nat_gateways - $nat_gateways"
if [ -n "$nat_gateways" ]; then
  for nat_gateway in $nat_gateways; do
    ${aws_cmd} ec2 delete-nat-gateway --region ${AWS_DEFAULT_REGION} --nat-gateway-id ${nat_gateway}
  done
fi

network_interfaces=$(${aws_cmd} ec2 describe-network-interfaces --region ${AWS_DEFAULT_REGION} --filters Name="tag:kubernetes.io/cluster/${clusterId}",Values="owned" --query 'NetworkInterfaces[].NetworkInterfaceId' --output text)
echo "8 - Deleting network_interfaces - $nat_gateways"
if [ -n "$network_interfaces" ]; then
  for network_interface in $network_interfaces; do
    ${aws_cmd} ec2 delete-network-interface --region ${AWS_DEFAULT_REGION} --network-interface-id ${network_interface}
  done
fi

exit 0
