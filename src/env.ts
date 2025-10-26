export const env = {
    region: process.env.AWS_REGION || 'us-east-1',
    bucketName: process.env.BUCKET_NAME!,
    queueUrl: process.env.JOBS_QUEUE_URL!,
    cdnBaseUrl: process.env.CDN_BASE_URL!,
    openAiSecretId: process.env.OPENAI_SECRET_ID!
};
