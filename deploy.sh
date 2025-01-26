# To use this rudimentary deployment script, you need to:
# - have aws-cli installed
# - have created the target bucket on S3
# - have created the IAM policy and user for full bucket access
# - have this profile referenced in your ~/.aws/credentials file
# - have retrieved your Cloudflare API key and email and stored them in files
# - have retrieved your Cloudflare resource id for the site to deploy

# AWS SETTINGS
aws_target_bucket="ethereum.mom"
aws_profile="ethereum-mom"

# CLOUDFLARE SETTINGS
cloudflare_resource_id="be19a35553a946d7c188df13f876c4d8"
cloudflare_email_file=".cloudflare-email"
cloudflare_api_file=".cloudflare-api"
cloudflare_email=$(cat "$cloudflare_email_file")
cloudflare_api_key=$(cat "$cloudflare_api_file")

# ALGOLIA SETTINGS
algolia_api_file=".algolia"
algolia_api_key=$(cat "$algolia_api_file")
algolia_application_id="BK3XWRO8GC"
algolia_index_name="ethereum-snippets"

# BUILD ALL FILES
npm run build

# UPLOAD ALL BUILT SITE FILES TO S3
aws s3 cp dist/ s3://$aws_target_bucket/dist --recursive --profile $aws_profile --acl public-read
aws s3 cp index.html s3://$aws_target_bucket/index.html --profile $aws_profile --acl public-read
aws s3 cp social.png s3://$aws_target_bucket/social.png --profile $aws_profile --acl public-read

# PURGE EVERYTHING ON CLOUDFLARE CDN TO RELOAD NEW FILES VERSIONS
curl -X DELETE "https://api.cloudflare.com/client/v4/zones/$cloudflare_resource_id/purge_cache" \
     -H "X-Auth-Email: $cloudflare_email" \
     -H "X-Auth-Key: $cloudflare_api_key" \
     -H "Content-Type: application/json" \
     --data '{"purge_everything":true}' | json_pp

# PURGE EVERYTHING FROM THE ALGOLIA INDEX
curl -X POST \
     -H "X-Algolia-API-Key: ${algolia_api_key}" \
     -H "X-Algolia-Application-Id: ${algolia_application_id}" \
    "https://${algolia_application_id}.algolia.net/1/indexes/${algolia_index_name}/clear"

# CREATE THE BATCH REQUEST TO POST DATA TO ALGOLIA
# Before using this, first ensure to have converted the data from ES6 to node
# format, as node cannot read ES6 js (e.g., use module.exports instead of export)
node src/data/convert_to_algolia.js

# FILL UP THE ALGOLIA INDEX WITH THE UPDATED DATA
curl -X POST \
     -H "X-Algolia-API-Key: ${algolia_api_key}" \
     -H "X-Algolia-Application-Id: ${algolia_application_id}" \
     --data-binary @algolia_batch_request.json \
    "https://${algolia_application_id}.algolia.net/1/indexes/${algolia_index_name}/batch"

# Command to get the zone id of the website to purge
# curl -X GET "https://api.cloudflare.com/client/v4/zones" \
#    -H "X-Auth-Email: $cloudflare_email" \
#    -H "X-Auth-Key: " \
#    -H "Content-Type: application/json"
