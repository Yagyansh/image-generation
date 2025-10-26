import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { SQSClient } from '@aws-sdk/client-sqs';
import { SecretsManagerClient, GetSecretValueCommand } from '@aws-sdk/client-secrets-manager';

export const s3 = new S3Client({});
export const sqs = new SQSClient({});
export const secrets = new SecretsManagerClient({});

export async function s3PutJson(bucket: string, key: string, obj: unknown) {
    await s3.send(new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        ContentType: 'application/json',
        Body: Buffer.from(JSON.stringify(obj))
    }));
}

export async function s3GetJson<T>(bucket: string, key: string): Promise<T | null> {
    try {
        const out = await s3.send(new GetObjectCommand({ Bucket: bucket, Key: key }));
        const body = await out.Body?.transformToString('utf-8');
        return body ? JSON.parse(body) as T : null;
    } catch {
        return null;
    }
}

export async function s3PutBytes(bucket: string, key: string, bytes: Buffer, contentType: string) {
    await s3.send(new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        ContentType: contentType,
        CacheControl: 'public, max-age=31536000, immutable',
        Body: bytes
    }));
}

export async function getSecretString(secretId: string) {
    const out = await secrets.send(new GetSecretValueCommand({ SecretId: secretId }));
    if (out.SecretString) return out.SecretString;
    if (out.SecretBinary) return Buffer.from(out.SecretBinary as Uint8Array).toString('utf-8');
    throw new Error('Secret has no payload');
}
