#!/bin/bash

createing()
{
# create vpc
myvpc=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --query Vpc.VpcId --output text)
echo "vpc created......"

# create subnet using vpc id
mysubnet1=$(aws ec2 create-subnet --vpc-id $myvpc --cidr-block 10.0.1.0/24 --availability-zone "us-west-2c" | jq -r '.Subnet.SubnetId')
mysubnet2=$(aws ec2 create-subnet --vpc-id $myvpc --cidr-block 10.0.0.0/24 --availability-zone "us-west-2d" | jq -r '.Subnet.SubnetId')
echo "subnet created....."

# create internetGateway
mygateway=$(aws ec2 create-internet-gateway --query InternetGateway.InternetGatewayId --output text)
echo "internetgateway created....."

#  attach the internet gateway to your VPC
aws ec2 attach-internet-gateway --vpc-id $myvpc --internet-gateway-id $mygateway 
echo "gateway attached to vpc successfully..."

# Create a custom route table for your VPC
myroutetable=$(aws ec2 create-route-table --vpc-id $myvpc --query RouteTable.RouteTableId --output text)
echo "route table created..."

# Create a route in the route table that points all traffic
aws ec2 create-route --route-table-id $myroutetable --destination-cidr-block 0.0.0.0/0 --gateway-id $mygateway
echo "route point to route table successfully..."

# associate route table to subnet
aws ec2 associate-route-table  --subnet-id $mysubnet1 --route-table-id $myroutetable
aws ec2 associate-route-table  --subnet-id $mysubnet2 --route-table-id $myroutetable
echo "associate route table successfully..."

# public ip to subnet
aws ec2 modify-subnet-attribute --subnet-id $mysubnet1 --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $mysubnet2 --map-public-ip-on-launch
echo "assigin public ip to subnets..."

# Create a key pair
aws ec2 create-key-pair --key-name sai --query "KeyMaterial" --output text > sai.pem
echo "key pair created succesfully..."

# read permisssion for the key
chmod 400 sai.pem
echo "read permission placed..."

# security group for ec2
securitygroup=$(aws ec2 create-security-group --group-name SSHAccess --description "Security group for SSH access" --vpc-id $myvpc --query GroupId --output text)

aws ec2 authorize-security-group-ingress --group-id $securitygroup --protocol tcp --port 22 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securitygroup --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securitygroup --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securitygroup --protocol tcp --port 9100 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securitygroup --protocol tcp --port 9090 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securitygroup --protocol tcp --port 3000 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $securitygroup --protocol tcp --port 3306 --cidr 0.0.0.0/0
echo "security group created successfully..."

# instance creation
myinstance=$(aws ec2 run-instances --image-id ami-0d70546e43a941d70 --count 1 --instance-type t2.micro --key-name sai --security-group-ids $securitygroup --subnet-id $mysubnet1 --user-data file://script.sh --query Instances[].InstanceId --output text)
echo "instance created successfully..."

publicip=$(aws ec2 describe-instances --instance-id $myinstance --query Reservations[].Instances[].NetworkInterfaces[].Association.PublicIp --output text)
echo "public ip created...."

# db creation 
aws rds create-db-instance \
    --db-instance-identifier test-mysql-instance \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --master-username admin \
    --master-user-password saigokul \
    --allocated-storage 20

# print output
echo "$myvpc"
echo "good"
echo "$mysubnet1"
echo "$mysubnet2"
echo "$mygateway"
echo "$myroutetable"
echo "$securitygroup"
echo "$myinstance"
echo "$publicip"



}


destroy()
{
# terminate EC2 instance
aws ec2 terminate-instances --instance-ids $myinstance
echo "my instance has been deleted successfully..."

sleep 70

<< now
# delete security group
aws ec2 delete-security-group --group-id $securitygroup
echo "security group deleted successfully..."
now

# Delete your subnets
aws ec2 delete-subnet --subnet-id $mysubnet1
aws ec2 delete-subnet --subnet-id $mysubnet2
echo "subnet deleted successfully..."

# Delete your custom route table
aws ec2 delete-route-table --route-table-id $myroutetable
echo "route table deleted successfully..."

# deleting key pair
aws ec2 delete-key-pair --key-name sai
rm sai.pem
echo "key pair successfully deleted in local and aws..."

# delete internet gateway for vpc
aws ec2 detach-internet-gateway --internet-gateway-id $mygateway --vpc-id $myvpc
echo "internet gateway from vpc deleted..."

# delete internet gateway
aws ec2 delete-internet-gateway --internet-gateway-id $mygateway
echo "gateway deleted successfully...."

# delete vpc
aws ec2 delete-vpc --vpc-id $myvpc
echo "vpc deleted successfully...."

}

while :
do
echo "Creating Infrasture : 1 "
echo "Deleting Infrasture : 2 "
read -p "value : " my
  if [[ $my -eq 1 ]]
  then
    createing
    echo "running"
  elif (($my==2))
  then
    destroy
    echo "not "
  fi
done



<< com
read -p "Enter the number : " op

if [[ $op -eq 0 ]]
then
  createing
  echo "Db created"
elif [[ $op -eq 1 ]]
then
  deleteingdb
  echo "db has been deleted"
fi
com

echo "$myvpc"
echo "good"
echo "$mysubnet1"
echo "$mysubnet2"
echo "$mygateway"
echo "$myroutetable"
echo "$securitygroup"
echo "$myinstance"
echo "$publicip"
