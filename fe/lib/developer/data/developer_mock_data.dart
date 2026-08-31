import '../models/developer_models.dart';

class DeveloperMockData {
  const DeveloperMockData._();

  static const DeveloperFileDoc mainFile =
      DeveloperFileDoc(
    id: 'BE/main.py',
    path: 'BE/main.py',
    name: 'main.py',
    extension: '.py',
    language: 'Python',
    layer: 'Backend API',
    module: 'BE',
    description:
        'Composition root FastAPI e principali endpoint StudentLab.',
    importance:
        'Entry point backend e orchestrazione API.',
    risk: DeveloperRiskLevel.critical,
    sourceType: DeveloperSourceType.remote,
    documented: true,
    outdated: false,
    changed: false,
    securityCritical: true,
    sizeBytes: 0,
    modifiedAt: null,
    contentHash: 'mock-main',
    functions: [
      DeveloperFunctionDoc(
        id: 'BE/main.py::api_login',
        name: 'api_login',
        signature: 'api_login(request, db)',
        description:
            'Endpoint di autenticazione.',
        calls: [
          'authenticate_user',
          'create_access_token',
        ],
        flows: [
          'Login',
        ],
        security: [
          'authentication',
        ],
        inputs: [
          'LoginRequest',
        ],
        outputs: [
          'LoginResponse',
        ],
        risk: DeveloperRiskLevel.critical,
      ),
    ],
    imports: [
      'services.auth',
      'models.user',
    ],
    flows: [
      'Login',
    ],
    securityNotes: [
      'Espone endpoint di autenticazione.',
    ],
  );

  static const DeveloperFileDoc authFile =
      DeveloperFileDoc(
    id: 'BE/services/auth.py',
    path: 'BE/services/auth.py',
    name: 'auth.py',
    extension: '.py',
    language: 'Python',
    layer: 'Backend Service',
    module: 'services',
    description:
        'Password hashing, verifica credenziali, JWT ed email verification.',
    importance:
        'Servizio centrale di autenticazione.',
    risk: DeveloperRiskLevel.critical,
    sourceType: DeveloperSourceType.remote,
    documented: true,
    outdated: false,
    changed: false,
    securityCritical: true,
    sizeBytes: 0,
    modifiedAt: null,
    contentHash: 'mock-auth',
    functions: [
      DeveloperFunctionDoc(
        id:
            'BE/services/auth.py::authenticate_user',
        name: 'authenticate_user',
        signature:
            'authenticate_user(db, email, password)',
        description:
            'Autentica un utente verificando le credenziali.',
        calls: [
          'verify_password',
        ],
        calledBy: [
          'api_login',
        ],
        flows: [
          'Login',
        ],
        security: [
          'password',
          'authentication',
        ],
        inputs: [
          'db',
          'email',
          'password',
        ],
        outputs: [
          'User | None',
        ],
        risk: DeveloperRiskLevel.critical,
      ),
    ],
    imports: [
      'models.user',
      'core.config',
    ],
    flows: [
      'Login',
      'Email Verification',
    ],
    securityNotes: [
      'Gestisce password e token.',
    ],
  );

  static const List<DeveloperFileDoc>
      files = [
    mainFile,
    authFile,
  ];

  static const DeveloperTreeNode tree =
      DeveloperTreeNode(
    id: 'root',
    name: 'FranzAmoroso/DMI-StudentLab',
    path: '',
    type: DeveloperNodeType.folder,
    children: [
      DeveloperTreeNode(
        id: 'BE',
        name: 'BE',
        path: 'BE',
        type: DeveloperNodeType.folder,
        children: [
          DeveloperTreeNode(
            id: 'BE/main.py',
            name: 'main.py',
            path: 'BE/main.py',
            type: DeveloperNodeType.file,
            documented: true,
            securityCritical: true,
            functionCount: 1,
          ),
          DeveloperTreeNode(
            id: 'BE/services',
            name: 'services',
            path: 'BE/services',
            type: DeveloperNodeType.folder,
            children: [
              DeveloperTreeNode(
                id: 'BE/services/auth.py',
                name: 'auth.py',
                path: 'BE/services/auth.py',
                type: DeveloperNodeType.file,
                documented: true,
                securityCritical: true,
                functionCount: 1,
              ),
            ],
          ),
        ],
      ),
    ],
  );

  static const List<DeveloperFlowDoc>
      flows = [
    DeveloperFlowDoc(
      id: 'login',
      name: 'Login',
      description:
          'Autenticazione utente e generazione token.',
      risk: DeveloperRiskLevel.critical,
      steps: [
        DeveloperFlowStep(
          order: 1,
          title: 'API login',
          file: 'BE/main.py',
          function: 'api_login',
          layer: 'Backend API',
          relation: 'CALLS',
          context:
              'Riceve le credenziali utente.',
          securityCritical: true,
        ),
        DeveloperFlowStep(
          order: 2,
          title: 'Authenticate user',
          file: 'BE/services/auth.py',
          function: 'authenticate_user',
          layer: 'Backend Service',
          relation: 'CALLS',
          context:
              'Verifica email e password.',
          securityCritical: true,
        ),
      ],
    ),
  ];
}