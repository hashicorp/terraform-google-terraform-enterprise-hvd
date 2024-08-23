# Deployment Customizations
<!-- TODO: -->
This page contains various deployment customizations as it relates to creating your TFE infrastructure, and their corresponding module input variables that you may additionally set to meet your own requirements where the default module values do not suffice. That said, all of the module input variables on this page are optional.

## Load Balancing

### Load Balancer Type
This module supports either creating a Network Load Balancer (NLB) or an Application Load Balancer (ALB) in front of the TFE Autoscaling Group. ***The default is NLB**, but the following input variable may be set to an ALB if desirable.

```hcl
lb_type = "alb"
```

### Load Balancer Scheme
This module supports creating a load balancer with either and `internal` or `internet-facing` load balancing scheme. **The default is `internal`**, but the following module boolean input variable may be set to configure the load balancer to be `internet-facing` (public) if desirable.

```hcl
lb_is_internal = false
```

## DNS
This module supports creating an _alias_ record in AWS Route53 for the TFE FQDN to resolve to the load balancer DNS name. To do so, the following module input variables may be set:

```hcl
create_route53_tfe_dns_record      = true
route53_tfe_hosted_zone_name       = "<example.com>"
route53_tfe_hosted_zone_is_private = false
```

## KMS
If you require the use of a customer-managed key(s) (CMK) to encrypt your AWS resources, the following module input variables may be set:

```hcl
ebs_kms_key_arn   = "<ebs-kms-key-arn>"
rds_kms_key_arn   = "<rds-kms-key-arn>"
s3_kms_key_arn    = "<s3-kms-key-arn>"
redis_kms_key_arn = "<redis-kms-key-arn>"
```

## Custom AMI
If you have a custom AWS AMI you would like to use, you can specify it via the following module input variables:

```hcl
ec2_ami_id    = "<custom-rhel-ami-id>"
ec2_os_distro = "<rhel>"
```
