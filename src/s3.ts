import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
const s3 = new S3Client({ region: process.env.AWS_REGION });

export async function uploadToS3(key: string, buffer: Buffer) {
    const bucket = process.env.IMAGE_S3_BUCKET!;
    const cmd = new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        Body: buffer,
        ContentType: 'image/png'
    });
    await s3.send(cmd);
    return { bucket, key };
}
