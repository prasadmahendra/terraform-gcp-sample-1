# Configuration

### Running Terraform on your workstation.

To install terraform on your workstation run the following homebrew commands

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

If you are using terraform on your workstation, you will need to install the Google Cloud SDK and authenticate using [User Application Default Credentials](https://cloud.google.com/sdk/gcloud/reference/auth/application-default).

```bash
brew install --cask google-cloud-sdk
gcloud auth application-default login
```

if you get a WARNING that `Cannot find a quota project to add to ADC. You might receive a "quota exceeded" or "API not enabled" error. Run $ gcloud auth application-default set-quota-project to add a quota project.` then run:

```bash
gcloud auth application-default set-quota-project spiffy-central
```

User ADCs do [expire](https://developers.google.com/identity/protocols/oauth2#expiration) and you can refresh them by running `gcloud auth application-default login`.

### Installing terraform

```bash
# For Ubuntu/Debian-based systems
# Add HashiCorp GPG key and repository
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install terraform

# For macOS
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Make sure gke-gcloud-auth-plugin is installed
gke-gcloud-auth-plugin --version  # if this runs and display a version then no need to install

# Install Google Cloud SDK for Ubuntu/Debian
# Add Google Cloud SDK repository
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt update
sudo apt install google-cloud-sdk google-cloud-sdk-gke-gcloud-auth-plugin kubectl

# For macOS and previously mentioned Linux commands
gcloud components install gke-gcloud-auth-plugin
gke-gcloud-auth-plugin --version

gcloud components install kubectl
gcloud components install terraform-tools
```

### Secrets 
Create a file secrets.tfvars in environments/dev/ and fill it in with the dev secrets from Secret Manager in GCP
```
datadog_api_key = ""
datadog_app_key = ""
elasticsearch_cloud_api_key = ""
```
After installing the pre-reqs, you must first initialize the terraform environment

First run this to ensure that you have initialized the dev environment
```bash
# For macOS
sh tf.sh -e dev -a init

# For Linux
bash tf.sh -e dev -a init
```

and then run this command
```bash
# For macOS
sh tf.sh -e dev -a plan

# For Linux
bash tf.sh -e dev -a plan
```

### Running Terraform outside of Google Cloud

If you are running terraform outside of Google Cloud, generate a service account key and set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to the path of the service account key. Terraform will use that key for authentication.

### Running Terraform on Apple silicon hardware
Running `terraform init` on an M1/M2 laptop can result in a similar error to:
```
template v2.2.0 does not have a package available for your current platform, darwin_arm64
```

The fix is to install an arm64 compatible version using `tfenv`:
```sh
brew uninstall terraform
brew install tfenv
TFENV_ARCH=amd64 tfenv install 1.6.1
tfenv use 1.6.1
```

### [](https://developer.hashicorp.com/terraform/language/settings/backends/gcs#impersonating-service-accounts)Impersonating Service Accounts

Terraform can impersonate a Google Service Account as described [here](https://cloud.google.com/iam/docs/creating-short-lived-service-account-credentials). A valid credential must be provided as mentioned in the earlier section and that identity must have the `roles/iam.serviceAccountTokenCreator` role on the service account you are impersonating.

### Terraform Samples
https://cloud.google.com/docs/terraform/samples
