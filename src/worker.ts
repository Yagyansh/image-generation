import AWS from 'aws-sdk';
import dotenv from 'dotenv';
import { generateImage } from './imageGen';
import { uploadToS3 } from './s3';
import { saveJobResult, updateJobStatus } from './db';

dotenv.config();
AWS.config.update({ region: process.env.AWS_REGION || 'us-east-1' });

const sqs = new AWS.SQS({ apiVersion: '2012-11-05' });
const queueUrl = process.env.SQS_QUEUE_URL!;

async function poll() {
    while (true) {
        try {
            const res = await sqs.receiveMessage({
                QueueUrl: queueUrl,
                MaxNumberOfMessages: 1,
                WaitTimeSeconds: 20
            }).promise();

            const msgs = res.Messages;
            if (!msgs || msgs.length === 0) continue;

            for (const m of msgs) {
                const body = JSON.parse(m.Body!);
                const jobId = body.jobId;
                try {
                    await updateJobStatus(jobId, 'PROCESSING');
                    const imgBuffer = await generateImage({ prompt: body.prompt, refs: body.refs || [] });
                    const key = `images/${jobId}/result.png`;
                    await uploadToS3(key, imgBuffer);
                    const cloudfrontUrl = `${process.env.CLOUDFRONT_URL}/${key}`;
                    await saveJobResult(jobId, key, cloudfrontUrl);
                    await sqs.deleteMessage({ QueueUrl: queueUrl, ReceiptHandle: m.ReceiptHandle! }).promise();
                } catch (err: any) {
                    console.error('job failed', err.message || err);
                    await updateJobStatus(jobId, 'FAILED', err.message || String(err));
                    // delete or leave depending on retry strategy - here we delete to avoid poison loop (DLQ should be configured in infra)
                    await sqs.deleteMessage({ QueueUrl: queueUrl, ReceiptHandle: m.ReceiptHandle! }).promise();
                }
            }
        } catch (err) {
            console.error('poll error', err);
            await new Promise(res => setTimeout(res, 2000));
        }
    }
}

poll().catch(err => {
    console.error('worker crashed', err);
    process.exit(1);
});
