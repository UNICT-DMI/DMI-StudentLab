import {
  issueSignedToken,
  presignUrl,
} from '@vercel/blob';

import type {
  VercelRequest,
  VercelResponse,
} from '@vercel/node';


const GROUP_MAX_FILE_SIZE =
  250 * 1024 * 1024;

const QUESTION_MAX_FILE_SIZE =
  50 * 1024 * 1024;

const UPLOAD_URL_LIFETIME_MS =
  15 * 60 * 1000;

const FILE_HASH_REGEX =
  /^[a-fA-F0-9]{64}$/;


const GROUP_ALLOWED_CONTENT_TYPES = [
  'application/pdf',
  'text/plain',
  'application/zip',
  'application/x-zip-compressed',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
];


const QUESTION_ALLOWED_CONTENT_TYPES = [
  'image/png',
  'image/jpeg',
  'image/webp',
  'application/pdf',
  'text/plain',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
];


const TEACHER_ALLOWED_CONTENT_TYPES = [
  'application/pdf',
  'application/zip',
  'application/x-zip-compressed',
  'application/msword',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/vnd.ms-excel',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/plain',
  'text/csv',
  'image/jpeg',
  'image/png',
  'image/webp',
];


type UploadKind =
  | 'group_material'
  | 'question_attachment'
  | 'teacher_material'
  | 'material_publication';


type UploadRequestBody = {
  upload_kind?: UploadKind;
  group_id?: number;
  subject_id?: number;
  pathname: string;
  content_type: string;
  size: number;
  file_hash: string;
  attachment_id?: string;
  upload_token?: string;
};


function getBackendUrl():
  string | null {
  const value =
    process.env
      .STUDENTLAB_API_URL
    ??
    process.env
      .FASTAPI_BASE_URL
    ??
    process.env
      .API_BASE_URL;

  if (!value) {
    return null;
  }

  return value
    .trim()
    .replace(
      /\/+$/,
      '',
    );
}


function getAuthorization(
  request: VercelRequest,
): string | null {
  const value =
    request.headers
      .authorization;

  if (
    typeof value !==
    'string' ||
    !value
      .toLowerCase()
      .startsWith(
        'bearer ',
      )
  ) {
    return null;
  }

  return value.trim();
}


function normalizeHash(
  value: unknown,
): string | null {
  if (
    typeof value !==
    'string'
  ) {
    return null;
  }

  const normalized =
    value
      .trim()
      .toLowerCase();

  if (
    !FILE_HASH_REGEX.test(
      normalized,
    )
  ) {
    return null;
  }

  return normalized;
}


function safePath(
  value: string,
): boolean {
  return (
    value.length >
    0 &&
    value.length <=
    1024 &&
    !value.startsWith(
      '/',
    ) &&
    !value.includes(
      '..',
    ) &&
    !value.includes(
      '\\',
    ) &&
    !value.includes(
      '\0',
    ) &&
    !value.includes(
      '\r',
    ) &&
    !value.includes(
      '\n',
    )
  );
}


async function parseJson(
  response: Response,
): Promise<
  Record<string, unknown>
> {
  try {
    const data =
      await response.json();

    if (
      data &&
      typeof data ===
      'object' &&
      !Array.isArray(
        data,
      )
    ) {
      return data as
        Record<
          string,
          unknown
        >;
    }
  } catch {
    return {};
  }

  return {};
}


export default async function handler(
  request: VercelRequest,
  response: VercelResponse,
) {
  if (
    request.method !==
    'POST'
  ) {
    response.setHeader(
      'Allow',
      'POST',
    );

    return response
      .status(405)
      .json({
        error:
          'Metodo non consentito.',
      });
  }

  const blobToken =
    process.env
      .StudentLab_READ_WRITE_TOKEN
    ??
    process.env
      .BLOB_READ_WRITE_TOKEN;

  const backendUrl =
    getBackendUrl();

  const authorization =
    getAuthorization(
      request,
    );

  if (!blobToken) {
    return response
      .status(500)
      .json({
        error:
          'Servizio Blob non configurato.',
      });
  }

  if (!backendUrl) {
    return response
      .status(500)
      .json({
        error:
          'Backend non configurato.',
      });
  }

  if (!authorization) {
    return response
      .status(401)
      .json({
        error:
          'Autenticazione richiesta.',
      });
  }

  try {
    const body =
      (
        typeof request.body ===
        'string'
          ? JSON.parse(
              request.body,
            )
          : request.body
      ) as UploadRequestBody;

    if (
      !body ||
      typeof body !==
      'object'
    ) {
      return response
        .status(400)
        .json({
          error:
            'Richiesta non valida.',
        });
    }

    if (
      typeof body.pathname !==
      'string' ||
      !safePath(
        body.pathname.trim(),
      )
    ) {
      return response
        .status(400)
        .json({
          error:
            'Percorso file non valido.',
        });
    }

    const pathname =
      body.pathname.trim();

    if (
      typeof body.content_type !==
      'string'
    ) {
      return response
        .status(400)
        .json({
          error:
            'Tipo file non valido.',
        });
    }

    const contentType =
      body.content_type
        .trim()
        .toLowerCase();

    if (
      !Number.isInteger(
        body.size,
      ) ||
      body.size <=
      0
    ) {
      return response
        .status(400)
        .json({
          error:
            'Dimensione file non valida.',
        });
    }

    const fileHash =
      normalizeHash(
        body.file_hash,
      );

    if (!fileHash) {
      return response
        .status(400)
        .json({
          error:
            'Hash SHA-256 non valido.',
        });
    }

    const uploadKind =
      body.upload_kind
      ??
      (
        pathname.startsWith(
          'questions/',
        )
          ? 'question_attachment'
          : pathname.startsWith(
              'teacher-materials/',
            )
            ? 'teacher_material'
            : pathname.startsWith(
                'material-publication/',
              )
              ? 'material_publication'
              : 'group_material'
      );

    if (
      uploadKind ===
      'question_attachment'
    ) {
      if (
        body.size >
        QUESTION_MAX_FILE_SIZE
      ) {
        return response
          .status(413)
          .json({
            error:
              'Il file supera la dimensione massima consentita di 50 MB.',
          });
      }

      if (
        !QUESTION_ALLOWED_CONTENT_TYPES.includes(
          contentType,
        )
      ) {
        return response
          .status(400)
          .json({
            error:
              'Tipo di file non supportato.',
          });
      }

      if (
        typeof body.attachment_id !==
        'string' ||
        typeof body.upload_token !==
        'string'
      ) {
        return response
          .status(400)
          .json({
            error:
              'Autorizzazione upload non valida.',
          });
      }

      const verifyResponse =
        await fetch(
          `${backendUrl}/question-attachments/verify-upload`,
          {
            method:
              'POST',
            headers: {
              Authorization:
                authorization,
              'Content-Type':
                'application/json',
            },
            body:
              JSON.stringify({
                upload_token:
                  body.upload_token,
                pathname,
                attachment_id:
                  body.attachment_id,
                mime_type:
                  contentType,
                size:
                  body.size,
                file_hash:
                  fileHash,
              }),
          },
        );

      const verified =
        await parseJson(
          verifyResponse,
        );

      if (
        !verifyResponse.ok ||
        verified.allowed !==
        true ||
        verified.pathname !==
        pathname
      ) {
        return response
          .status(
            verifyResponse.status >=
            400 &&
            verifyResponse.status <
            500
              ? verifyResponse.status
              : 403,
          )
          .json({
            error:
              typeof verified.detail ===
              'string'
                ? verified.detail
                : 'Caricamento non autorizzato.',
          });
      }
    } else if (
      uploadKind ===
      'teacher_material'
    ) {
      if (
        !pathname.startsWith(
          'teacher-materials/',
        )
      ) {
        return response
          .status(400)
          .json({
            error:
              'Percorso materiale docente non valido.',
          });
      }

      if (
        body.size >
        GROUP_MAX_FILE_SIZE
      ) {
        return response
          .status(413)
          .json({
            error:
              'Il file supera la dimensione massima consentita di 250 MB.',
          });
      }

      if (
        !TEACHER_ALLOWED_CONTENT_TYPES.includes(
          contentType,
        )
      ) {
        return response
          .status(400)
          .json({
            error:
              'Tipo di file non supportato.',
          });
      }

      if (
        !Number.isInteger(
          body.subject_id,
        ) ||
        !body.subject_id ||
        body.subject_id <=
        0 ||
        typeof body.upload_token !==
        'string'
      ) {
        return response
          .status(400)
          .json({
            error:
              'Autorizzazione upload non valida.',
          });
      }

      const verifyResponse =
        await fetch(
          `${backendUrl}/teacher/materials/verify-upload`,
          {
            method:
              'POST',
            headers: {
              Authorization:
                authorization,
              'Content-Type':
                'application/json',
            },
            body:
              JSON.stringify({
                subject_id:
                  body.subject_id,
                pathname,
                mime_type:
                  contentType,
                size:
                  body.size,
                file_hash:
                  fileHash,
                upload_token:
                  body.upload_token,
              }),
          },
        );

      const verified =
        await parseJson(
          verifyResponse,
        );

      if (
        !verifyResponse.ok ||
        verified.allowed !==
        true ||
        verified.pathname !==
        pathname ||
        verified.subject_id !==
        body.subject_id
      ) {
        return response
          .status(
            verifyResponse.status >=
            400 &&
            verifyResponse.status <
            500
              ? verifyResponse.status
              : 403,
          )
          .json({
            error:
              typeof verified.detail ===
              'string'
                ? verified.detail
                : 'Caricamento non autorizzato.',
          });
      }
    } else if (
      uploadKind ===
      'material_publication'
    ) {
      if (
        !pathname.startsWith(
          'material-publication/',
        )
      ) {
        return response
          .status(400)
          .json({
            error:
              'Percorso pubblicazione materiale non valido.',
          });
      }

      if (
        body.size >
        GROUP_MAX_FILE_SIZE
      ) {
        return response
          .status(413)
          .json({
            error:
              'Il file supera la dimensione massima consentita di 250 MB.',
          });
      }

      if (
        !GROUP_ALLOWED_CONTENT_TYPES.includes(
          contentType,
        )
      ) {
        return response
          .status(400)
          .json({
            error:
              'Tipo di file non supportato.',
          });
      }

      if (
        !Number.isInteger(
          body.subject_id,
        ) ||
        !body.subject_id ||
        body.subject_id <=
        0 ||
        typeof body.upload_token !==
        'string'
      ) {
        return response
          .status(400)
          .json({
            error:
              'Autorizzazione upload non valida.',
          });
      }

      const verifyResponse =
        await fetch(
          `${backendUrl}/material_publication/verify-upload`,
          {
            method:
              'POST',
            headers: {
              Authorization:
                authorization,
              'Content-Type':
                'application/json',
            },
            body:
              JSON.stringify({
                subject_id:
                  body.subject_id,
                pathname,
                mime_type:
                  contentType,
                size:
                  body.size,
                file_hash:
                  fileHash,
                upload_token:
                  body.upload_token,
              }),
          },
        );

      const verified =
        await parseJson(
          verifyResponse,
        );

      if (
        !verifyResponse.ok ||
        verified.allowed !==
        true ||
        verified.pathname !==
        pathname ||
        verified.subject_id !==
        body.subject_id
      ) {
        return response
          .status(
            verifyResponse.status >= 400 &&
            verifyResponse.status < 500
              ? verifyResponse.status
              : 403,
          )
          .json({
            error:
              typeof verified.detail ===
              'string'
                ? verified.detail
                : 'Caricamento non autorizzato.',
          });
      }
    } else {
      if (
        !pathname.startsWith(
          'groups/group_',
        )
      ) {
        return response
          .status(400)
          .json({
            error:
              'Percorso materiale gruppo non valido.',
          });
      }

      if (
        body.size >
        GROUP_MAX_FILE_SIZE
      ) {
        return response
          .status(413)
          .json({
            error:
              'Il file supera la dimensione massima consentita di 250 MB.',
          });
      }

      if (
        !GROUP_ALLOWED_CONTENT_TYPES.includes(
          contentType,
        )
      ) {
        return response
          .status(400)
          .json({
            error:
              'Tipo di file non supportato.',
          });
      }

      if (
        !Number.isInteger(
          body.group_id,
        ) ||
        !body.group_id ||
        body.group_id <= 0 ||
        typeof body.upload_token !==
          'string' ||
        body.upload_token
          .trim()
          .length === 0
      ) {
        return response
          .status(400)
          .json({
            error:
              'Autorizzazione upload gruppo non valida.',
          });
      }

      const verifyResponse =
        await fetch(
          `${backendUrl}/group_material_verify_upload/${body.group_id}`,
          {
            method:
              'POST',
            headers: {
              Authorization:
                authorization,
              'Content-Type':
                'application/json',
            },
            body:
              JSON.stringify({
                group_id:
                  body.group_id,
                pathname,
                mime_type:
                  contentType,
                size:
                  body.size,
                file_hash:
                  fileHash,
                upload_token:
                  body.upload_token,
              }),
          },
        );

      const verified =
        await parseJson(
          verifyResponse,
        );

      if (
        !verifyResponse.ok ||
        verified.allowed !==
          true ||
        verified.pathname !==
          pathname ||
        verified.group_id !==
          body.group_id
      ) {
        return response
          .status(
            verifyResponse.status >=
              400 &&
            verifyResponse.status <
              500
              ? verifyResponse.status
              : 403,
          )
          .json({
            error:
              typeof verified.detail ===
                'string'
                ? verified.detail
                : 'Caricamento non autorizzato.',
          });
      }
    }

    const validUntil =
      Date.now() +
      UPLOAD_URL_LIFETIME_MS;

    const signedToken =
      await issueSignedToken({
        pathname,
        operations: [
          'put',
        ],
        validUntil,
        maximumSizeInBytes:
          body.size,
        allowedContentTypes: [
          contentType,
        ],
        token:
          blobToken,
      });

    const {
      presignedUrl,
    } =
      await presignUrl(
        signedToken,
        {
          pathname,
          operation:
            'put',
          access:
            'private',
          validUntil,
          maximumSizeInBytes:
            body.size,
          allowedContentTypes: [
            contentType,
          ],
          addRandomSuffix:
            false,
        },
      );

    if (
      typeof presignedUrl !==
      'string' ||
      !presignedUrl.startsWith(
        'https://',
      )
    ) {
      return response
        .status(500)
        .json({
          error:
            'Non è stato possibile preparare un caricamento sicuro.',
        });
    }

    return response
      .status(200)
      .json({
        allowed:
          true,
        upload_kind:
          uploadKind,
        pathname,
        attachment_id:
          body.attachment_id
          ?? null,
        subject_id:
          uploadKind ===
            'teacher_material' ||
          uploadKind ===
            'material_publication'
            ? body.subject_id
              ?? null
            : null,
        presigned_url:
          presignedUrl,
        content_type:
          contentType,
        size:
          body.size,
        file_hash:
          fileHash,
        valid_until:
          validUntil,
      });
  } catch {
    return response
      .status(500)
      .json({
        error:
          'Non è stato possibile preparare il caricamento del file.',
      });
  }
}