# docker-config

### Installation Setup
Just perform a github build and deploy action

### Configuration setup
1. Setup an org secret BAO_ADMIN_PASSWORD to anything you want
1. Create a PAT token scoped to org secrets r/w and store as BAO_GH_TOKEN
1. Run the bootstrap gha

### Onboarding an app
1. Simply pass the github repo name (no domain) to the onboard gha

### Offboarding an app
1. Sam as onboarding