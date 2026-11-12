# feedbacks-railway

Railway wrapper image for [Feedbacks](https://github.com/Softinator-TechLabs/feedbacks-oss) (Apache-2.0): derives the
production configuration (HTTPS S3 endpoint, database URL, stable organization id), creates the bucket and the owner
account from environment variables, then starts the unmodified upstream server. Published as `ghcr.io/bon5co/feedbacks-railway`.
