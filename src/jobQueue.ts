import AWS from 'aws-sdk';
AWS.config.update({ region: process.env.AWS_REGION || 'us-east-1' });
const sqs = new AWS.SQS({ apiVersion: '2012-11-05' });

export async function enqueueJob(payload: { jobId: string; prompt: string; refs: string[] }) {
    const queueUrl = process.env.SQS_QUEUE_URL!;
    const params = {
        QueueUrl: queueUrl,
        MessageBody: JSON.stringify(payload)
    };
    await sqs.sendMessage(params).promise();
}
