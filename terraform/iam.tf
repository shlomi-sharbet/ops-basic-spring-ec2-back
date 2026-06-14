
# 1. יצירת משתמש IAM
resource "aws_iam_user" "s3_user" {
  name = "s3_user"
  path = "/"

  tags = {
    Name = "s3_user"
  }
}

# 2. יצירת מפתחות גישה (Access Key & Secret Key)
resource "aws_iam_access_key" "s3_user_key" {
  user = aws_iam_user.s3_user.name
}

# 3. חיבור המשתמש להרשאת AmazonS3FullAccess (Managed Policy)
resource "aws_iam_user_policy_attachment" "s3_full_access" {
  user       = aws_iam_user.s3_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# 4. הדפסת המפתחות לפלט (זהירות: זה ידפיס אותם לטרמינל ול-state)
output "s3_user_access_key" {
  description = "Access Key for s3_user"
  value       = aws_iam_access_key.s3_user_key.id
}

output "s3_user_secret_key" {
  description = "Secret Key for s3_user"
  value       = aws_iam_access_key.s3_user_key.secret
  sensitive   = true
}
