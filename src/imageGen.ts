import axios from 'axios';

export async function generateImage(opts: { prompt: string; refs: string[] }): Promise<Buffer> {
    const provider = process.env.IMAGE_PROVIDER || 'mock';
    if (provider === 'mock') {
        // tiny 1x1 PNG
        const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';
        return Buffer.from(pngBase64, 'base64');
    }

    if (provider === 'openai') {
        const key = process.env.IMAGE_API_KEY;
        if (!key) throw new Error('IMAGE_API_KEY not set');
        const res = await axios.post(
            'https://api.openai.com/v1/images/generations',
            { prompt: opts.prompt, n: 1, size: '1024x1024', response_format: 'b64_json' },
            { headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' } }
        );
        const b64 = res.data.data[0].b64_json;
        return Buffer.from(b64, 'base64');
    }

    if (provider === 'replicate') {
        throw new Error('Replicate provider not implemented in scaffold');
    }

    throw new Error('Unsupported IMAGE_PROVIDER');
}
