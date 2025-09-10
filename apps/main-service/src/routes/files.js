const express = require('express');
const multer = require('multer');
const multerS3 = require('multer-s3');
const AWS = require('aws-sdk');
const { v4: uuidv4 } = require('uuid');

const router = express.Router();

// AWS S3 설정
const s3 = new AWS.S3({
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  region: process.env.AWS_REGION || 'ap-northeast-2'
});

const BUCKET_NAME = process.env.S3_BUCKET_NAME || 'eks-msa-learning-platform-files';

// Multer S3 설정
const upload = multer({
  storage: multerS3({
    s3: s3,
    bucket: BUCKET_NAME,
    acl: 'private', // 보안을 위해 private으로 설정
    key: function (req, file, cb) {
      const fileExtension = file.originalname.split('.').pop();
      const fileName = `${uuidv4()}.${fileExtension}`;
      cb(null, `uploads/${new Date().getFullYear()}/${new Date().getMonth() + 1}/${fileName}`);
    },
    metadata: function (req, file, cb) {
      cb(null, {
        originalName: file.originalname,
        uploadedBy: req.headers['x-user-id'] || 'anonymous',
        uploadedAt: new Date().toISOString()
      });
    }
  }),
  limits: {
    fileSize: parseInt(process.env.MAX_FILE_SIZE) || 10 * 1024 * 1024, // 10MB
    files: 1
  },
  fileFilter: function (req, file, cb) {
    // 허용된 파일 타입 검사
    const allowedTypes = process.env.ALLOWED_FILE_TYPES || 'image/*,application/pdf,text/*';
    const allowedMimeTypes = allowedTypes.split(',').map(type => type.trim());
    
    const isAllowed = allowedMimeTypes.some(allowedType => {
      if (allowedType.endsWith('/*')) {
        return file.mimetype.startsWith(allowedType.replace('/*', '/'));
      }
      return file.mimetype === allowedType;
    });

    if (isAllowed) {
      cb(null, true);
    } else {
      cb(new Error(`File type ${file.mimetype} is not allowed`), false);
    }
  }
});

// 파일 업로드
router.post('/upload', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        error: 'No file uploaded',
        timestamp: new Date().toISOString()
      });
    }

    const fileData = {
      id: uuidv4(),
      filename: req.file.key,
      originalName: req.file.originalname,
      size: req.file.size,
      mimeType: req.file.mimetype,
      uploadedAt: new Date().toISOString(),
      url: req.file.location,
      bucket: req.file.bucket,
      etag: req.file.etag
    };

    // 실제 구현에서는 데이터베이스에 파일 정보 저장
    // 여기서는 응답으로만 반환
    res.status(201).json({
      message: 'File uploaded successfully',
      file: fileData,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('File upload error:', error);
    res.status(500).json({
      error: 'File upload failed',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// 파일 목록 조회
router.get('/', async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    
    // S3에서 파일 목록 조회
    const params = {
      Bucket: BUCKET_NAME,
      Prefix: 'uploads/',
      MaxKeys: parseInt(limit)
    };

    const s3Response = await s3.listObjectsV2(params).promise();
    
    const files = await Promise.all(
      s3Response.Contents.map(async (object) => {
        try {
          // 파일 메타데이터 조회
          const headParams = {
            Bucket: BUCKET_NAME,
            Key: object.Key
          };
          
          const headResponse = await s3.headObject(headParams).promise();
          
          return {
            id: object.Key.split('/').pop().split('.')[0], // 파일명에서 UUID 추출
            filename: object.Key,
            originalName: headResponse.Metadata.originalname || object.Key.split('/').pop(),
            size: object.Size,
            mimeType: headResponse.ContentType,
            uploadedAt: object.LastModified.toISOString(),
            url: await getSignedUrl(object.Key), // 임시 다운로드 URL 생성
            etag: object.ETag
          };
        } catch (error) {
          console.error(`Error getting metadata for ${object.Key}:`, error);
          return {
            id: object.Key.split('/').pop().split('.')[0],
            filename: object.Key,
            originalName: object.Key.split('/').pop(),
            size: object.Size,
            mimeType: 'application/octet-stream',
            uploadedAt: object.LastModified.toISOString(),
            url: await getSignedUrl(object.Key),
            etag: object.ETag
          };
        }
      })
    );

    res.json({
      files,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: s3Response.KeyCount,
        hasMore: s3Response.IsTruncated
      },
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('File list error:', error);
    
    // S3 연결 실패 시 목업 데이터 반환
    if (error.code === 'NetworkingError' || error.code === 'UnknownEndpoint') {
      const mockFiles = getMockFiles();
      res.json({
        files: mockFiles,
        pagination: { page: 1, limit: 20, total: mockFiles.length, hasMore: false },
        fallback: true,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(500).json({
        error: 'Failed to fetch files',
        message: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }
});

// 파일 다운로드 URL 생성
router.get('/:id/download', async (req, res) => {
  try {
    const { id } = req.params;
    
    // 실제 구현에서는 데이터베이스에서 파일 정보 조회
    // 여기서는 S3에서 직접 검색
    const listParams = {
      Bucket: BUCKET_NAME,
      Prefix: 'uploads/'
    };

    const s3Response = await s3.listObjectsV2(listParams).promise();
    const file = s3Response.Contents.find(obj => obj.Key.includes(id));

    if (!file) {
      return res.status(404).json({
        error: 'File not found',
        fileId: id,
        timestamp: new Date().toISOString()
      });
    }

    const downloadUrl = await getSignedUrl(file.Key, 3600); // 1시간 유효

    res.json({
      downloadUrl,
      expiresIn: 3600,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error(`File download URL error for ${req.params.id}:`, error);
    res.status(500).json({
      error: 'Failed to generate download URL',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// 파일 삭제
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // S3에서 파일 검색
    const listParams = {
      Bucket: BUCKET_NAME,
      Prefix: 'uploads/'
    };

    const s3Response = await s3.listObjectsV2(listParams).promise();
    const file = s3Response.Contents.find(obj => obj.Key.includes(id));

    if (!file) {
      return res.status(404).json({
        error: 'File not found',
        fileId: id,
        timestamp: new Date().toISOString()
      });
    }

    // S3에서 파일 삭제
    const deleteParams = {
      Bucket: BUCKET_NAME,
      Key: file.Key
    };

    await s3.deleteObject(deleteParams).promise();

    res.json({
      message: 'File deleted successfully',
      fileId: id,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error(`File deletion error for ${req.params.id}:`, error);
    res.status(500).json({
      error: 'Failed to delete file',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// S3 Signed URL 생성 헬퍼 함수
async function getSignedUrl(key, expiresIn = 900) {
  const params = {
    Bucket: BUCKET_NAME,
    Key: key,
    Expires: expiresIn
  };

  return s3.getSignedUrl('getObject', params);
}

// 목업 파일 데이터
function getMockFiles() {
  return [
    {
      id: 'mock-file-1',
      filename: 'uploads/2024/1/sample-document.pdf',
      originalName: 'sample-document.pdf',
      size: 1024000,
      mimeType: 'application/pdf',
      uploadedAt: '2024-01-01T10:00:00Z',
      url: 'https://example.com/mock-download-url-1',
      etag: '"mock-etag-1"'
    },
    {
      id: 'mock-file-2',
      filename: 'uploads/2024/1/sample-image.jpg',
      originalName: 'sample-image.jpg',
      size: 512000,
      mimeType: 'image/jpeg',
      uploadedAt: '2024-01-02T14:30:00Z',
      url: 'https://example.com/mock-download-url-2',
      etag: '"mock-etag-2"'
    }
  ];
}

// 에러 핸들링 미들웨어
router.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        error: 'File too large',
        message: `File size exceeds ${process.env.MAX_FILE_SIZE || '10MB'} limit`,
        timestamp: new Date().toISOString()
      });
    }
    if (error.code === 'LIMIT_FILE_COUNT') {
      return res.status(400).json({
        error: 'Too many files',
        message: 'Only one file can be uploaded at a time',
        timestamp: new Date().toISOString()
      });
    }
  }
  
  if (error.message.includes('File type') && error.message.includes('not allowed')) {
    return res.status(400).json({
      error: 'Invalid file type',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }

  next(error);
});

module.exports = router;