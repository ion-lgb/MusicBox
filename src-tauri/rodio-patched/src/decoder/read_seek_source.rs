use std::io::{Read, Result, Seek, SeekFrom};

use symphonia::core::io::MediaSource;

pub struct ReadSeekSource<T: Read + Seek + Send + Sync> {
    inner: T,
    len: Option<u64>,
}

impl<T: Read + Seek + Send + Sync> ReadSeekSource<T> {
    /// Instantiates a new `ReadSeekSource<T>` by taking ownership and wrapping the provided
    /// `Read + Seek`er.
    pub fn new(mut inner: T) -> Self {
        // Calculate byte_len at construction time
        let len = Self::compute_len(&mut inner);
        ReadSeekSource { inner, len }
    }

    fn compute_len(inner: &mut T) -> Option<u64> {
        let current = inner.seek(SeekFrom::Current(0)).ok()?;
        let end = inner.seek(SeekFrom::End(0)).ok()?;
        inner.seek(SeekFrom::Start(current)).ok()?;
        Some(end)
    }
}

impl<T: Read + Seek + Send + Sync> MediaSource for ReadSeekSource<T> {
    fn is_seekable(&self) -> bool {
        true
    }

    fn byte_len(&self) -> Option<u64> {
        self.len
    }
}

impl<T: Read + Seek + Send + Sync> Read for ReadSeekSource<T> {
    fn read(&mut self, buf: &mut [u8]) -> Result<usize> {
        self.inner.read(buf)
    }
}

impl<T: Read + Seek + Send + Sync> Seek for ReadSeekSource<T> {
    fn seek(&mut self, pos: SeekFrom) -> Result<u64> {
        self.inner.seek(pos)
    }
}
