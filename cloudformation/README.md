## Steps for the initial AWS CloudFormation setup in order to have auto deploy on git push

#### Clone git repo

- Clone repo `cicd`

#### Generate SSH keypair for ec2 instances

- Login to AWS Management Console

- Open Services -> EC2

- Scroll down to `NETWORK & SECURITY` section

- Click `Key Pairs`

- Click button `Create Key Pair`

- Set key pair name as `TheAppCloudformationKeypair`

- Leave `File format` as `pem`

- Click button `Create key pair`

- Save `TheAppCloudformationKeypair.pem` file to your `~/.ssh/ folder`

#### Create service role for CloudFormation `cloudformation/init.yaml`

- Open Services -> IAM -> Roles

- Click button `Create role`

- Click link `CloudFormation`

- Click button `Next: Permissions`

- Click button `Create policy` (new windown/tag is opened)

- Select tab `JSON`

- Insert JSON:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "*",
                "iam:*",
                "route53:*",
                "ec2:*"
            ],
            "Resource": "*"
        }
    ]
}
```

- Click button `Review policy`

- Set `Name` as `CloudFormationRole` and `Description` as `Service Role for CloudFormation`

- Click button `Create policy` and close page since it was opened in new window/tab

- Go back to previous browser tab where you was before new window/tab with policy was opened, to the role creation page, and find just created policy with name `CloudFormationRole` and set checkbox to enabled state

- Click button `Next: Tags`

- Enter `Name` into `Key` field and `CloudFormationRole` into `Value` field

- Click button `Next: Review`

- Set `Role name` as `CloudFormationRole`

- Click button `Create role`

#### Create initial stack using `cloudformation/init.yaml` file

- Open Services -> CloudFormation

- Click button `Create Stack`

- Select option `Template is ready`

- Select Option `Upload a template file`

- Click button `Choose file`

- Select file `cloudformation/init.yaml` from the `cicd` folder which was clonned from git repo

- Click button `Next`

- Enter `Stack name` as you desire (e.g. `ThAppInitStack`)

- Update `AppNameParameter` as you desire or leave it as default `TheApp`. Please note that the prefix of key pair name `TheAppCloudformationKeypair` created above must mutch the value of `AppNameParameter`

- Click button `Next`

- For `Tags` section enter `Name` into `Key` field and `TheAppInitStack` into `Value` field and leave all other field with default values

- Select `IAM role name` as `CloudFormationRole`

- Click button `Next`

- Review stack which will be created

- Set checkmark `I acknowledge that AWS CloudFormation might create IAM resources with custom names.`

- Click button `Create stack`

- Wait stack to be created

#### Setup github workflow

- Generate SSH keypair on local box or use existing one if you already have

- - Put the value of private key (should look like this `-----BEGIN RSA PRIVATE KEY-----`) into github secrets under `AWS_SSH_PRIVATE_KEY` variable (replace new lines with `\n` and no spaces between lines, just `\n`)

- Open AWS -> Services -> IAM -> Users -> Select `TheAppCodeCommit` user >- Select tab `Security Credentials`

- Scroll down to the section `SSH keys for AWS CodeCommit`

- Click button `Upload SSH public key`

- Paste the value of puiblic key (should look like `ssh-rsa AA...`) as single line, no new lines and no \n must be present

- Click button `Upload SSH public Key`

- Copy the value of `SSH key ID` column to clipboard

- Put the value of `SSH key ID` (should look like this `APKAS6GKXXW5KVHNLI3B`) into github secrets under `AWS_SSH_USER` variable

- Now every time you make a push to the `master` branch it will trigger github workflow and pass code to the AWS CodeCommit for further processing and deploy

#### Review and approve/reject stack changeset

- Open AWS -> Services -> CodePipeLine -> TheApp -> Scroll down and click button `Review` -> Enter any message and click button `Approve` (approve will be requested on every push to the `master` branch)

- Wait for another stack to be created

#### Manually validate SSL certificated created by stack

- Open AWS -> Certificate Manager

- Expand record `AppApiSslCertificate`

- Expand record ` api.theapp.tld` and copy Name and Value

- Create exactly the same certificate in `us-east-1 (N.Virginia)` region due to CloudFront works only with certificates from that region

- Open AWS -> Services -> Route 53 -> Hosted zones -> `theapp.tld`

- Click button `Create Record Set`

- Insert into `Name` field the value copied from Certificate Manager (e.g. `_98d64d7f5009d1f3d61baa06de8cfa40` part from copied value `_98d64d7f5009d1f3d61baa06de8cfa40.api.theapp.tld.`)

- Select tyle as `CNAME`

- Set `TTL` to `300`

- Set `Value` field to copied value from Certificate Manager (e.g. `_6b6b442a55f01d55aca7736a0de99f98.auiqqraehs.acm-validations.aws.`)

- Open AWS -> Services -> Route 53 -> Hosted zones -> `theapp.tld` -> Copy value of NS record of `theapp.tld.` -> Update registrar NS records with the ns servers copied from AWS

- Wait for NS records to be updated (depends on the TTL set on registrar side, usually 15 minutes but can take up to 48 hours)

#### Verify UI and backend URLs are accessible and working

- Backend is available at `https://api.theapp.tld`

- Frontend is available at `https://www.theapp.tld`
