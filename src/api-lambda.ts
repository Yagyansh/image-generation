import { APIGatewayProxyHandlerV2 } from 'aws-lambda';
import { ulid } from 'ulid';
import { env } from './env.js';
import { s3GetJson, s3PutJson, sqs } from './aws.js';
import { SendMessageCommand } from '@aws-sdk/client-sqs';
import { ImageJob, JobManifest } from './types.js';

const manifestKey = (jobId: string) => `jobs/${jobId}.json`;
const imageUrl = (jobId: string) => `${env.cdnBaseUrl}/images/${jobId}.png`;

export const handler: APIGatewayProxyHandlerV2 = async (event) => {
    const route = `${event.requestContext.http.method} ${event.rawPath}`;

    if (route === 'POST /images') {
        const body = JSON.parse(event.body ?? '{}') as Omit<ImageJob, 'jobId'>;
        if (!body?.prompt || typeof body.prompt !== 'string') {
            return { statusCode: 400, body: JSON.stringify({ error: 'prompt required' }) };
        }

        const jobId = `job_${ulid()}`;
        const manifest: JobManifest = {
            jobId,
            status: 'queued',
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString(),
            request: {
                prompt: body.prompt,
                size: body.size || '1024x1024',
                quality: body.quality || 'high',
                background: body.background || 'opaque',
                references: body.references || []
            }
        };

        await s3PutJson(env.bucketName, manifestKey(jobId), manifest);

        await sqs.send(new SendMessageCommand({
            QueueUrl: env.queueUrl,
            MessageBody: JSON.stringify({ ...manifest.request, jobId })
        }));

        return {
            statusCode: 202,
            body: JSON.stringify({
                jobId,
                statusUrl: `/jobs/${jobId}`,
                imageUrl: imageUrl(jobId)
            })
        };
    }

    if (route.startsWith('GET /jobs/')) {
        const jobId = event.rawPath.split('/').pop()!;
        const manifest = await s3GetJson<JobManifest>(env.bucketName, manifestKey(jobId));
        if (!manifest) return { statusCode: 404, body: JSON.stringify({ error: 'not found' }) };
        return {
            statusCode: 200,
            body: JSON.stringify({
                jobId: manifest.jobId,
                status: manifest.status,
                error: manifest.error,
                imageUrl: manifest.imageKey ? imageUrl(manifest.jobId) : undefined
            })
        };
    }

    return { statusCode: 404, body: 'Not found' };
};
