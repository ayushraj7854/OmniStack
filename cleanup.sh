#!/bin/bash

set -e

REGION="ap-south-1"

echo "=========================================="
echo "Destroying SLURM Cluster Resources"
echo "=========================================="
echo ""
echo "WARNING: This will delete ALL resources!"
echo "Press Ctrl+C to cancel, or wait 10 seconds..."
sleep 10

echo ""
echo "Step 1: Terminating EC2 instances..."

# Get all instance IDs
INSTANCE_IDS=$(aws ec2 describe-instances \
    --region $REGION \
    --filters "Name=tag:Name,Values=login,controller,compute*" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text)

if [ ! -z "$INSTANCE_IDS" ]; then
    echo "Terminating instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_IDS
    echo "Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --region $REGION --instance-ids $INSTANCE_IDS
    echo "✓ Instances terminated"
else
    echo "No instances to terminate"
fi

echo ""
echo "Step 2: Deleting NAT Gateway..."
sleep 5

VPC_ID=$(aws ec2 describe-vpcs \
    --region $REGION \
    --filters "Name=tag:Name,Values=ansible-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text)

if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
    NAT_GW_ID=$(aws ec2 describe-nat-gateways \
        --region $REGION \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
        --query 'NatGateways[0].NatGatewayId' \
        --output text)
    
    if [ "$NAT_GW_ID" != "None" ] && [ ! -z "$NAT_GW_ID" ]; then
        echo "Deleting NAT Gateway: $NAT_GW_ID"
        aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id $NAT_GW_ID
        echo "Waiting for NAT Gateway to delete..."
        sleep 60
        echo "✓ NAT Gateway deleted"
    fi
fi

echo ""
echo "Step 3: Releasing Elastic IPs..."

EIP_ALLOC_IDS=$(aws ec2 describe-addresses \
    --region $REGION \
    --filters "Name=tag:Name,Values=nat-gateway-eip" \
    --query 'Addresses[].AllocationId' \
    --output text)

for ALLOC_ID in $EIP_ALLOC_IDS; do
    if [ ! -z "$ALLOC_ID" ]; then
        echo "Releasing: $ALLOC_ID"
        aws ec2 release-address --region $REGION --allocation-id $ALLOC_ID
    fi
done

echo ""
echo "Step 4: Deleting security groups..."
sleep 10

for SG_NAME in private-sg login-sg; do
    SG_ID=$(aws ec2 describe-security-groups \
        --region $REGION \
        --filters "Name=group-name,Values=$SG_NAME" \
        --query 'SecurityGroups[0].GroupId' \
        --output text 2>/dev/null)
    
    if [ "$SG_ID" != "None" ] && [ ! -z "$SG_ID" ]; then
        echo "Deleting: $SG_NAME"
        aws ec2 delete-security-group --region $REGION --group-id $SG_ID
    fi
done

echo ""
echo "Step 5: Deleting subnets..."

if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --region $REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[].SubnetId' \
        --output text)
    
    for SUBNET_ID in $SUBNET_IDS; do
        echo "Deleting: $SUBNET_ID"
        aws ec2 delete-subnet --region $REGION --subnet-id $SUBNET_ID
    done
fi

echo ""
echo "Step 6: Deleting route tables..."

if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
    RT_IDS=$(aws ec2 describe-route-tables \
        --region $REGION \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' \
        --output text)
    
    for RT_ID in $RT_IDS; do
        echo "Deleting: $RT_ID"
        aws ec2 delete-route-table --region $REGION --route-table-id $RT_ID
    done
fi

echo ""
echo "Step 7: Deleting internet gateway..."

if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --region $REGION \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text)
    
    if [ "$IGW_ID" != "None" ] && [ ! -z "$IGW_ID" ]; then
        aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
        aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $IGW_ID
    fi
fi

echo ""
echo "Step 8: Deleting VPC..."

if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
    aws ec2 delete-vpc --region $REGION --vpc-id $VPC_ID
    echo "✓ VPC deleted"
fi

echo ""
echo "Step 9: Cleaning local files..."
rm -f hosts.ini connection_info.txt /tmp/munge.key
echo "✓ Cleanup complete"

echo ""
echo "=========================================="
echo "✓ ALL RESOURCES DESTROYED"
echo "=========================================="
