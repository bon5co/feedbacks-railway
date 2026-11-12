// Waits for the S3 endpoint and creates the bucket when missing. Runs from /app so the upstream's
// @aws-sdk/client-s3 resolves.
import { S3Client, CreateBucketCommand, HeadBucketCommand } from "@aws-sdk/client-s3";

const client = new S3Client({
  endpoint: process.env.S3_ENDPOINT,
  region: process.env.S3_REGION,
  forcePathStyle: true,
  credentials: { accessKeyId: process.env.S3_ACCESS_KEY_ID, secretAccessKey: process.env.S3_SECRET_ACCESS_KEY },
});
const bucket = process.env.S3_BUCKET;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function retry(label, fn, attempts = 60) {
  let last;
  for (let i = 1; i <= attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      last = e;
      if (i % 10 === 1) console.error(`railway-init: ${label} attempt ${i} failed: ${e.name}: ${e.message}`);
      await sleep(3000);
    }
  }
  throw last;
}

const mode = process.argv[2];
if (mode === "wait-s3") {
  await retry("storage", async () => {
    const r = await fetch(`${process.env.S3_ENDPOINT}/minio/health/live`);
    if (!r.ok) throw new Error(`health ${r.status}`);
  });
} else if (mode === "bucket") {
  await retry("bucket", async () => {
    try {
      await client.send(new HeadBucketCommand({ Bucket: bucket }));
    } catch (e) {
      if (e.$metadata?.httpStatusCode === 404 || e.name === "NotFound") {
        await client.send(new CreateBucketCommand({ Bucket: bucket }));
        console.error(`railway-init: created bucket ${bucket}`);
        return;
      }
      throw e;
    }
  });
} else {
  throw new Error("usage: railway-init.mjs wait-s3|bucket");
}
