import React, { useState, useRef } from 'react';
import { apiClient } from '../services/apiClient';

interface UploadedFile {
  id: string;
  filename: string;
  originalName: string;
  size: number;
  mimeType: string;
  uploadedAt: string;
  url: string;
}

export const FileUpload: React.FC = () => {
  const [uploadedFiles, setUploadedFiles] = useState<UploadedFile[]>([]);
  const [uploading, setUploading] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [dragOver, setDragOver] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileSelect = (files: FileList | null) => {
    if (!files || files.length === 0) return;
    
    const file = files[0];
    uploadFile(file);
  };

  const uploadFile = async (file: File) => {
    try {
      setUploading(true);
      setUploadProgress(0);
      setError(null);

      const formData = new FormData();
      formData.append('file', file);

      const uploadedFile = await apiClient.uploadFile(formData, (progress) => {
        setUploadProgress(progress);
      });

      setUploadedFiles(prev => [uploadedFile, ...prev]);
      setUploadProgress(100);
      
      // 성공 메시지 표시 후 진행률 초기화
      setTimeout(() => {
        setUploadProgress(0);
      }, 2000);
    } catch (err) {
      setError('파일 업로드에 실패했습니다.');
      console.error('File upload failed:', err);
    } finally {
      setUploading(false);
    }
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    handleFileSelect(e.dataTransfer.files);
  };

  const handleDeleteFile = async (fileId: string) => {
    try {
      await apiClient.deleteFile(fileId);
      setUploadedFiles(prev => prev.filter(file => file.id !== fileId));
    } catch (err) {
      setError('파일 삭제에 실패했습니다.');
      console.error('File deletion failed:', err);
    }
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('ko-KR');
  };

  const getFileIcon = (mimeType: string) => {
    if (mimeType.startsWith('image/')) return '🖼️';
    if (mimeType.startsWith('video/')) return '🎥';
    if (mimeType.startsWith('audio/')) return '🎵';
    if (mimeType.includes('pdf')) return '📄';
    if (mimeType.includes('document') || mimeType.includes('word')) return '📝';
    if (mimeType.includes('spreadsheet') || mimeType.includes('excel')) return '📊';
    return '📁';
  };

  return (
    <div>
      <div className="page-header">
        <h1 className="page-title">파일 업로드</h1>
        <p className="page-description">S3 스토리지에 파일을 업로드하고 관리할 수 있습니다.</p>
      </div>

      {error && (
        <div className="alert alert-danger mb-20">{error}</div>
      )}

      <div className="card mb-20">
        <div className="card-header">
          <h3 className="card-title">파일 업로드</h3>
        </div>
        <div className="card-body">
          <div 
            className={`upload-zone ${dragOver ? 'drag-over' : ''}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            onClick={() => fileInputRef.current?.click()}
          >
            <div className="upload-content">
              <div className="upload-icon">📁</div>
              <p className="upload-text">
                파일을 드래그하여 놓거나 클릭하여 선택하세요
              </p>
              <p className="upload-hint">
                최대 파일 크기: 10MB
              </p>
            </div>
            <input
              ref={fileInputRef}
              type="file"
              style={{ display: 'none' }}
              onChange={(e) => handleFileSelect(e.target.files)}
              disabled={uploading}
            />
          </div>

          {uploading && (
            <div className="upload-progress">
              <div className="progress-bar">
                <div 
                  className="progress-fill"
                  style={{ width: `${uploadProgress}%` }}
                ></div>
              </div>
              <p className="progress-text">
                업로드 중... {uploadProgress}%
              </p>
            </div>
          )}
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <h3 className="card-title">업로드된 파일 ({uploadedFiles.length}개)</h3>
        </div>
        <div className="card-body">
          {uploadedFiles.length === 0 ? (
            <div className="text-center p-20">
              <p>업로드된 파일이 없습니다.</p>
            </div>
          ) : (
            <div className="files-list">
              {uploadedFiles.map(file => (
                <div key={file.id} className="file-item">
                  <div className="file-icon">
                    {getFileIcon(file.mimeType)}
                  </div>
                  <div className="file-info">
                    <div className="file-name">{file.originalName}</div>
                    <div className="file-details">
                      <span className="file-size">{formatFileSize(file.size)}</span>
                      <span className="file-date">{formatDate(file.uploadedAt)}</span>
                    </div>
                  </div>
                  <div className="file-actions">
                    <a 
                      href={file.url} 
                      target="_blank" 
                      rel="noopener noreferrer"
                      className="btn btn-primary btn-sm"
                    >
                      다운로드
                    </a>
                    <button 
                      className="btn btn-danger btn-sm"
                      onClick={() => handleDeleteFile(file.id)}
                    >
                      삭제
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};