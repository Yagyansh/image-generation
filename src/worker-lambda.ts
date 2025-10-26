import { SQSHandler, SQSBatchResponse } from 'aws-lambda';
import OpenAI from 'openai';
import { env } from './env.js';
import { s3GetJson, s3PutBytes, s3PutJson, getSecretString } from './aws.js';
import { ImageJob, JobManifest } from './types.js';

let cachedKey: string | null = null;
async function openAi() {
    if (!cachedKey) cachedKey = await getSecretString(env.openAiSecretId);
    return new OpenAI({ apiKey: cachedKey! });
}

const manifestKey = (jobId: string) => `jobs/${jobId}.json`;

async function process(job: ImageJob) {
    const now = new Date().toISOString();
    const existing = await s3GetJson<JobManifest>(env.bucketName, manifestKey(job.jobId));
    const base: JobManifest = existing || {
        jobId: job.jobId,
        status: 'processing',
        createdAt: now,
        updatedAt: now,
        request: {
            prompt: job.prompt,
            size: job.size || '1024x1024',
            quality: job.quality || 'high',
            background: job.background || 'opaque',
            references: job.references || []
        }
    };
    base.status = 'processing';
    base.updatedAt = now;
    await s3PutJson(env.bucketName, manifestKey(job.jobId), base);

    try {
        const client = await openAi();
        const rsp = await client.images.generate({
            model: 'gpt-image-1',
            prompt: base.request.prompt,
            size: base.request.size || '1024x1024',
            quality: base.request.quality || 'high',
            background: base.request.background || 'opaque'
        });
        const b64 = rsp.data[0].b64_json!;
        const bytes = Buffer.from(b64, 'base64');
        const imgKey = `images/${job.jobId}.png`;
        await s3PutBytes(env.bucketName, imgKey, bytes, 'image/png');

        const done: JobManifest = { ...base, status: 'done', updatedAt: new Date().toISOString(), imageKey: imgKey };
        await s3PutJson(env.bucketName, manifestKey(job.jobId), done);
    } catch (e: any) {
        const failed: JobManifest = { ...base, status: 'failed', updatedAt: new Date().toISOString(), error: e?.message || 'generation failed' };
        await s3PutJson(env.bucketName, manifestKey(job.jobId), failed);
        throw e;
    }
}

export const handler: SQSHandler = async (event): Promise<SQSBatchResponse> => {
    const failures: { itemIdentifier: string }[] = [];
    await Promise.all(event.Records.map(async (r, i) => {
        try { await process(JSON.parse(r.body)); }
        catch { failures.push({ itemIdentifier: r.messageId || String(i) }); }
    }));
    return { batchItemFailures: failures };
};
