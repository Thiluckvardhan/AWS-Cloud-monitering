#!/bin/bash

AWS_PROFILE=default
AWS_REGION=us-east-1
EMAIL="paras.dhiman030804@gmail.com"
REPORT="/tmp/aws_status_report.txt"
STATE_FILE="/tmp/aws_previous_state.json"

# Create a temporary JSON file if it doesn't exist
if [[ ! -f $STATE_FILE ]]; then
  echo '{}' > $STATE_FILE
fi

# Load previous counts
read_previous() {
  jq -r --arg key "$1" '.[$key] // 0' "$STATE_FILE"
}

# Save current counts
save_current() {
  jq --arg key "$1" --argjson val "$2" '. + {($key): $val}' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

# Colorized change indicator
print_change() {
  local current=$1
  local previous=$2
  local delta=$((current - previous))
  if (( delta > 0 )); then
    echo -e " (📈 +$delta)"
  elif (( delta < 0 )); then
    echo -e " (📉 \e[31m$delta\e[0m)"
  else
    echo ""
  fi
}

# Start building report
{
  echo -e "=============================="
  echo -e "🧾 AWS Service Status Report"
  echo -e "📅 Date: $(date)"
  echo -e "==============================\n"

  ############################
  # 1. EC2 INSTANCES
  ############################
  echo -e "🖥️  EC2 Instances"
  echo "------------------------------"
  CURRENT_INSTANCES=$(aws ec2 describe-instances --profile $AWS_PROFILE --region $AWS_REGION --query 'Reservations[*].Instances[*].InstanceId' --output text)
  INSTANCE_COUNT=$(echo "$CURRENT_INSTANCES" | wc -w)
  PREV_INSTANCE_COUNT=$(read_previous "ec2_instances")
  echo -n "Total Instances: $INSTANCE_COUNT"
  print_change "$INSTANCE_COUNT" "$PREV_INSTANCE_COUNT"
  save_current "ec2_instances" "$INSTANCE_COUNT"

  # Instance state table
  aws ec2 describe-instances --profile $AWS_PROFILE --region $AWS_REGION \
    --query 'Reservations[*].Instances[*].{ID:InstanceId,State:State.Name}' --output table

  # Detect New and Terminated Instances
  IFS=$'\n' read -d '' -r -a CURRENT_ARRAY <<< "$CURRENT_INSTANCES"
  PREV_ARRAY=($(read_previous "ec2_instance_ids" | jq -r '.[]'))
  NEW_INSTANCES=($(comm -13 <(printf "%s\n" "${PREV_ARRAY[@]}" | sort) <(printf "%s\n" "${CURRENT_ARRAY[@]}" | sort)))
  TERMINATED_INSTANCES=($(comm -23 <(printf "%s\n" "${PREV_ARRAY[@]}" | sort) <(printf "%s\n" "${CURRENT_ARRAY[@]}" | sort)))

  [[ ${#NEW_INSTANCES[@]} -gt 0 ]] && echo -e "\n🆕 New Instances:" && printf "  - %s\n" "${NEW_INSTANCES[@]}"
  [[ ${#TERMINATED_INSTANCES[@]} -gt 0 ]] && echo -e "\n❌ Terminated Instances:" && printf "  - %s\n" "${TERMINATED_INSTANCES[@]}"

  jq -n --argjson arr "$(printf '%s\n' "${CURRENT_ARRAY[@]}" | jq -R . | jq -s .)" '{"ec2_instance_ids": $arr}' > "${STATE_FILE}.tmp2"
  jq -s '.[0] * .[1]' "$STATE_FILE" "${STATE_FILE}.tmp2" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"

  echo -e "\n"

  ############################
  # 2. VPCs
  ############################
  echo -e "🌐 VPCs"
  echo "------------------------------"
  VPC_COUNT=$(aws ec2 describe-vpcs --profile $AWS_PROFILE --region $AWS_REGION \
    --query 'Vpcs[*].VpcId' --output text | wc -w)
  PREV_VPC_COUNT=$(read_previous "vpcs")
  echo -n "Total VPCs: $VPC_COUNT"
  print_change "$VPC_COUNT" "$PREV_VPC_COUNT"
  save_current "vpcs" "$VPC_COUNT"

  aws ec2 describe-vpcs --profile $AWS_PROFILE --region $AWS_REGION \
    --query 'Vpcs[*].{VPCID:VpcId,State:State}' --output table
  echo -e "\n"

  ############################
  # 3. IAM USERS
  ############################
  echo -e "👤 IAM Users"
  echo "------------------------------"
  IAM_USER_COUNT=$(aws iam list-users --profile $AWS_PROFILE --query 'Users[*].UserName' --output text | wc -w)
  PREV_USER_COUNT=$(read_previous "iam_users")
  echo -n "Total IAM Users: $IAM_USER_COUNT"
  print_change "$IAM_USER_COUNT" "$PREV_USER_COUNT"
  save_current "iam_users" "$IAM_USER_COUNT"

  aws iam list-users --profile $AWS_PROFILE \
    --query 'Users[*].{UserName:UserName,Created:CreateDate}' --output table
  echo -e "\n"

  ############################
  # 4. IAM ROLES
  ############################
  echo -e "🎭 IAM Roles"
  echo "------------------------------"
  IAM_ROLE_COUNT=$(aws iam list-roles --profile $AWS_PROFILE \
    --query 'Roles[*].RoleName' --output text | wc -w)
  PREV_ROLE_COUNT=$(read_previous "iam_roles")
  echo -n "Total IAM Roles: $IAM_ROLE_COUNT"
  print_change "$IAM_ROLE_COUNT" "$PREV_ROLE_COUNT"
  save_current "iam_roles" "$IAM_ROLE_COUNT"

  aws iam list-roles --profile $AWS_PROFILE \
    --query 'Roles[*].{RoleName:RoleName,Created:CreateDate}' --output table
  echo -e "\n"

  ############################
  # 5. S3 BUCKETS
  ############################
  echo -e "🪣 S3 Buckets"
  echo "------------------------------"
  S3_BUCKET_COUNT=$(aws s3 ls --profile $AWS_PROFILE | wc -l)
  PREV_BUCKET_COUNT=$(read_previous "s3_buckets")
  echo -n "Total S3 Buckets: $S3_BUCKET_COUNT"
  print_change "$S3_BUCKET_COUNT" "$PREV_BUCKET_COUNT"
  save_current "s3_buckets" "$S3_BUCKET_COUNT"

  aws s3 ls --profile $AWS_PROFILE
  echo -e "\n✅ Report generated successfully."

} > "$REPORT" 2>&1

# Send Email (now properly spaced for mobile)
mail -a "Content-Type: text/plain; charset=UTF-8" \
     -s "✅ AWS Report: $(date '+%Y-%m-%d %H:%M')" "$EMAIL" < "$REPORT"

