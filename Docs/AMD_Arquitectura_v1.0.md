**AMD**

Ars Medica Digitalis

Documento de Arquitectura e Historias de Usuario

*Paso 0 — Pre-Desarrollo (MVP)*

Versión 1.0  |  Febrero 2026

| Campo | Valor |
| :---- | :---- |
| Proyecto | AMD — Ars Medica Digitalis |
| Versión de documento | 1.0 |
| Fecha de creación | Febrero 2026 |
| Estado | Borrador — Aprobación Pendiente |
| Stack iOS | Swift 6.2.3 · SwiftUI · SwiftData · CloudKit |
| Target mínimo | iOS 26.0 |
| Xcode | 26.3+ |
| Paradigma de concurrencia | Approachable Concurrency (Swift 6.2) |
| Sincronización | iCloud Private Zone (NSPersistentCloudKitContainer) |

# **0\. Hallazgos de Investigación Pre-Proyecto**

Antes de iniciar el diseño se realizó una consulta de la documentación actualizada de Swift, SwiftData y CloudKit. Los hallazgos a continuación fundamentan las decisiones arquitectónicas del proyecto.

## **0.1 Swift 6.2 — Approachable Concurrency**

| ℹ️  Swift 6.2 introduce un cambio filosófico mayor en concurrencia. La especificación original ("modo Strict") es reemplazada por "Approachable Concurrency", igualmente segura pero con menor fricción de desarrollo. |
| :---- |

| Feature Swift 6.2 | Impacto en AMD |
| :---- | :---- |
| \-default-isolation MainActor | Los módulos son @MainActor por defecto. Elimina la contaminación async en ViewModels. |
| Atributo @concurrent | Opt-in explícito para paralelismo real. Se usa solo en ICD11Service y operaciones de I/O pesadas. |
| Async functions en contexto del caller | Menos boilerplate en ViewModels. Llamadas async sin propagación innecesaria. |
| InlineArray\<N,E\> y Span | Estructuras de datos en stack (20-30% más rápido). Útiles para listas de resultados del CIE-11. |

## **0.2 SwiftData iOS 26 — Model Inheritance**

| 💡  SwiftData en Xcode 26 incorpora herencia de modelos (@Model con clases padre/hijo) y resuelve bugs críticos de versiones anteriores. Para AMD: la entidad Professional puede servir de base para futuras especializaciones (PsychologistProfile, DentistProfile). |
| :---- |
| ⚠️  Advertencia de la comunidad: casos de uso complejos con colaboración entre usuarios frecuentemente migran a Core Data \+ CloudKit Sharing tras consultar con DTS de Apple. Para el MVP de AMD (zona privada, un usuario), SwiftData es suficiente. Se documenta como deuda técnica potencial para v2. |

## **0.3 CloudKit \+ SwiftData — Reglas de Oro Confirmadas**

| ⚠️  Regla absoluta: TODAS las propiedades deben tener valor por defecto o ser opcionales. TODAS las relaciones deben ser opcionales (?). No son sugerencias — son requisitos. El incumplimiento hace que iCloud deje de sincronizar silenciosamente. |
| :---- |

* SwiftData actualmente solo accede a zonas PRIVADAS de CloudKit (no compartidas ni públicas).

* Cada profesional tiene su propia zona privada. Los datos de un paciente son exclusivos del profesional que lo creó.

* CloudKit puede descargar objetos "hijos" antes que sus "padres" — las relaciones opcionales previenen crashes en este escenario.

## **0.4 API CIE-11 — Detalles Técnicos**

* Autenticación: OAuth 2.0 Client Credentials (token endpoint: https://icdaccessmanagement.who.int/connect/token).

* Linearización correcta para clínica: MMS (Mortality and Morbidity Statistics) — endpoint: https://id.who.int/icd/release/11/{version}/mms/search.

* API v2 actual (camelCase en respuestas). Soporte multilenguaje vía Accept-Language header.

* El token tiene vida útil limitada (\~1 hora). Debe cachearse y renovarse proactivamente.

# **1\. Stack Tecnológico Actualizado**

| ℹ️  Esta sección incorpora todas las actualizaciones derivadas de la investigación. Reemplaza cualquier especificación anterior. |
| :---- |

## **1.1 Especificaciones de Plataforma**

| Componente | Especificación | Justificación |
| :---- | :---- | :---- |
| Lenguaje | Swift 6.2.3+ | Versión estable más reciente. Approachable Concurrency. |
| UI Framework | SwiftUI (100% nativo) | Ciclo de vida puro. Sin UIViewRepresentable salvo excepción justificada. |
| Persistencia Local | SwiftData \+ @Model | ORM moderno con sincronización CloudKit integrada. |
| Sincronización | CloudKit (Zona Privada) | Serverless, gratuito para el usuario, integrado con Apple ID. |
| IDE | Xcode 26.3+ | Soporte de iOS 26 SDK. AI Assistant integrado. |
| Target mínimo | iOS 26.0 | Alineado con SwiftData inheritance y Liquid Glass UI. |
| Diseño visual | Liquid Glass (iOS 26\) | Nuevo estándar del sistema. No usar hacks visuales previos. |

## **1.2 Mandamientos de Concurrencia — Actualizado**

| Categoría | Regla | Estado |
| :---- | :---- | :---- |
| Paradigma | Approachable Concurrency: \-default-isolation MainActor | OBLIGATORIO |
| Paralelismo | @concurrent en servicios de I/O (ICD11Service, AttachmentService) | OBLIGATORIO |
| Actores | @ModelActor para operaciones SwiftData en background | OBLIGATORIO |
| ViewModels | @Observable (reemplaza ObservableObject \+ @Published) | OBLIGATORIO |
| Bindings en Vista | @Bindable para crear bindings desde @Observable | OBLIGATORIO |
| APIs obsoletas | DispatchQueue, callbacks, NotificationCenter directo | PROHIBIDO |
| Warnings | Tolerancia Cero. El proyecto debe compilar sin warnings. | PROHIBIDO |
| Predicados | NSPredicate / predicados String (Objective-C) | PROHIBIDO |
| Dependencias | Librerías externas (SPM) salvo necesidad justificada | EVITAR |

## **1.3 Principios de Calidad de Código**

| Principio | Aplicación en AMD |
| :---- | :---- |
| DRY (Don't Repeat Yourself) | Lógica de predicados, formateo de fechas y validación de campos en extensiones/funciones genéricas reutilizables. |
| Comentarios en español | Obligatorios. Explican el POR QUÉ de las decisiones, no el QUÉ obvio del código. |
| String Catalogs (.xcstrings) | Todos los textos de la UI. Nunca literales de String directamente en las vistas. |
| \#Predicate macro | Única forma permitida de construir consultas en SwiftData. Type-safe en tiempo de compilación. |
| Modelos Sendable | Todos los tipos que cruzan boundaries de actor deben conformar a Sendable. |
| NavigationStack tipado | navigationDestination(for:) con tipos específicos. NavigationView está vetado. |

# **2\. Modelado de Datos — SwiftData para CloudKit**

Las siguientes entidades representan el núcleo del dominio clínico. Cada decisión de diseño está fundamentada en los requisitos de CloudKit y en la integridad médico-legal de la historia clínica.

## **2.1 Principios de Diseño Transversales**

| Principio | Regla Concreta | Razón |
| :---- | :---- | :---- |
| CloudKit Compatibility | Todas las propiedades con valor por defecto o tipo opcional | Requisito iCloud. Sin esto, la sincronización falla silenciosamente. |
| Relaciones opcionales | Toda relación declarada como \[Tipo\]? \= \[\] | CloudKit puede descargar hijos antes que padres. La opcionalidad previene crashes. |
| Borrado lógico | Campo deletedAt: Date? \= nil en Patient | La historia clínica es un documento médico-legal. Nunca se elimina físicamente. |
| Trazabilidad | createdAt y updatedAt en todas las entidades | Auditoría clínica y resolución de conflictos de sincronización. |
| UUID en cliente | id: UUID \= UUID() generado en el dispositivo | Coherencia de identidad antes de que CloudKit asigne su propio recordName. |
| Tipos planos para CloudKit | Enums persistidos como String; no tipos compuestos | CloudKit no soporta tipos anidados no-primitivos en los registros. |

## **2.2 Entidad: Professional**

Representa al profesional de salud propietario de la cuenta. Es el anchor de todos los datos: todo viaja en su zona privada de CloudKit.

| @Model final class Professional {     // ID generado en cliente para coherencia entre dispositivos     var id: UUID \= UUID()     // Datos de identidad     var fullName: String \= ""     var licenseNumber: String \= ""    // ⚠️ Sensible — zona privada iCloud     var specialty: String \= ""        // Ej: "Psicología", "Odontología"     var email: String \= ""           // ⚠️ Sensible     // Configuración regional     var preferredLanguage: String \= "es"     var createdAt: Date \= Date()     var updatedAt: Date \= Date()     // Opcional por requisito de CloudKit. En la lógica de negocio,     // un Professional siempre tiene patients (nunca nil en práctica).     @Relationship(deleteRule: .cascade, inverse: \\Patient.professional)     var patients: \[Patient\]? \= \[\] } |
| :---- |

## **2.3 Entidad: Patient**

El sujeto central de la historia clínica. Implementa borrado lógico mediante deletedAt — nunca se elimina físicamente.

| @Model final class Patient {     var id: UUID \= UUID()     // Datos demográficos     var firstName: String \= ""     var lastName: String \= ""     var dateOfBirth: Date \= Date()     var biologicalSex: String \= ""      // String en lugar de enum para compatibilidad CloudKit     var nationalId: String \= ""         // ⚠️ CRÍTICO — ver Mapa de Seguridad     var email: String \= ""             // ⚠️ Sensible     var phoneNumber: String \= ""       // ⚠️ Sensible     var address: String \= ""     // BORRADO LÓGICO: cuando deletedAt \!= nil, el paciente está inactivo.     // El \#Predicate filtra { $0.deletedAt \== nil } en la vista principal.     // CloudKit conserva el registro histórico sin excepción.     var deletedAt: Date? \= nil     var createdAt: Date \= Date()     var updatedAt: Date \= Date()     var professional: Professional? \= nil     @Relationship(deleteRule: .cascade, inverse: \\Session.patient)     var sessions: \[Session\]? \= \[\]     // Computed property — no se persiste, solo para la UI     var fullName: String { "\\(firstName) \\(lastName)" }     var isDeleted: Bool { deletedAt \!= nil } } |
| :---- |

## **2.4 Entidad: Session**

Cada encuentro clínico entre el profesional y el paciente. El campo notes es el corazón narrativo de la historia clínica.

| @Model final class Session {     var id: UUID \= UUID()     var sessionDate: Date \= Date()     var sessionType: String \= "presencial"  // "presencial" | "videollamada" | "telefónica"     var durationMinutes: Int \= 50     var notes: String \= ""              // ⚠️ CRÍTICO — contenido clínico privado     var chiefComplaint: String \= ""     // Motivo de consulta     var treatmentPlan: String \= ""     var status: String \= "completada"   // "programada" | "completada" | "cancelada"     var createdAt: Date \= Date()     var updatedAt: Date \= Date()     var patient: Patient? \= nil     @Relationship(deleteRule: .cascade, inverse: \\Diagnosis.session)     var diagnoses: \[Diagnosis\]? \= \[\]     @Relationship(deleteRule: .cascade, inverse: \\Attachment.session)     var attachments: \[Attachment\]? \= \[\] } |
| :---- |

## **2.5 Entidad: Diagnosis**

Diagnóstico CIE-11 asociado a una sesión. Los datos del código se persisten como snapshot inmutable al momento del diagnóstico — garantizando legibilidad histórica sin dependencia de la API externa.

| 💡  Desnormalización controlada e intencional: guardar código, título y URI directamente en SwiftData (en lugar de solo el ID) asegura que un diagnóstico de 2025 sea perfectamente legible en 2035, independientemente de cambios en la API del CIE-11. |
| :---- |

| @Model final class Diagnosis {     var id: UUID \= UUID()     // Snapshot CIE-11 — inmutable una vez guardado.     // icdVersion permite saber qué release de la clasificación se usó,     // ya que los códigos pueden cambiar de descripción entre versiones.     var icdCode: String \= ""           // Ej: "6A70"     var icdTitle: String \= ""          // Ej: "Single episode depressive disorder"     var icdTitleEs: String \= ""        // Título en español si disponible     var icdURI: String \= ""           // URI canónico del WHO     var icdVersion: String \= "2024-01" // Release del CIE-11 usado al diagnosticar     // Contexto clínico     var diagnosisType: String \= "principal"  // "principal" | "secundario" | "diferencial"     var severity: String \= ""     var clinicalNotes: String \= ""    // ⚠️ CRÍTICO — contenido clínico     var diagnosedAt: Date \= Date()     var createdAt: Date \= Date()     var session: Session? \= nil } |
| :---- |

## **2.6 Entidad: Attachment**

Adjuntos a una sesión (estudios, imágenes, documentos escaneados). El binario se almacena como CloudKit Asset, no dentro del registro, para respetar el límite de 1MB por record.

| @Model final class Attachment {     var id: UUID \= UUID()     var fileName: String \= ""     var fileType: String \= ""           // MIME type: "application/pdf", "image/jpeg"     var fileSizeBytes: Int \= 0     // Referencia al CKAsset en CloudKit. Los binarios grandes     // van como Assets para evitar el límite de 1MB por registro.     var cloudKitAssetURL: String \= ""     // Path local temporal en el FileSystem del dispositivo (cache).     // No se sincroniza directamente — se reconstruye desde el Asset.     var localCachePath: String \= ""     var uploadStatus: String \= "pendiente"  // "pendiente" | "subiendo" | "completado" | "error"     var createdAt: Date \= Date()     var session: Session? \= nil } |
| :---- |

## **2.7 Mapa de Seguridad de Datos**

| ℹ️  La zona privada de iCloud solo es visible para el propietario de la cuenta. Para el MVP este nivel es aceptable. La encriptación en cliente (CryptoKit) es la estrategia de v2 para datos críticos. |
| :---- |

| Campo | Entidad | Nivel de Riesgo | Estrategia MVP | Estrategia v2 |
| :---- | :---- | :---- | :---- | :---- |
| nationalId | Patient | 🔴 Crítico | Zona privada iCloud | CryptoKit antes del upload |
| notes | Session | 🔴 Crítico | Zona privada iCloud | CryptoKit antes del upload |
| clinicalNotes | Diagnosis | 🔴 Crítico | Zona privada iCloud | CryptoKit antes del upload |
| email, phoneNumber | Patient | 🟡 Medio | Zona privada iCloud | CryptoKit opcional |
| licenseNumber | Professional | 🟡 Medio | Zona privada iCloud | Sin cambios necesarios |
| icdCode, icdTitle | Diagnosis | 🟢 Bajo | Sin restricción | Sin restricción |
| sessionDate, status | Session | 🟢 Bajo | Sin restricción | Sin restricción |

# **3\. Historias de Usuario — MVP**

| HU-01 — Registro y Perfil Profesional |
| :---- |
| *Como* **profesional de salud nuevo***, quiero* **crear y gestionar mi perfil profesional***, para que* **mis datos de identidad y matrícula estén disponibles en todos mis dispositivos de forma segura.** |
| **Criterios de Aceptación** Given: soy un usuario nuevo que abre AMD por primera vez. When: completo nombre, especialidad y matrícula. Then: mi perfil se crea localmente, sincroniza con iCloud y accedo a la pantalla principal. Given: ya tengo perfil.  When: modifico mi especialidad.  Then: los cambios se reflejan en todos mis dispositivos en \<30 segundos. |

| HU-02 — Alta de Paciente |
| :---- |
| *Como* **profesional***, quiero* **registrar un nuevo paciente con sus datos demográficos***, para* **iniciar su historia clínica digital centralizada.** |
| **Criterios de Aceptación** Given: estoy en la lista de pacientes.  When: toco "Nuevo Paciente" y completo los campos mínimos (nombre, apellido, fecha de nacimiento).  Then: el paciente aparece con isActive \= true y deletedAt \= nil, sincronizado con iCloud. Given: estoy sin conexión a internet.  When: guardo un nuevo paciente.  Then: se persiste localmente en SwiftData y sincroniza automáticamente al recuperar conectividad. |

| HU-03 — Gestión del Padrón (Modificación y Baja Lógica) |
| :---- |
| *Como* **profesional***, quiero* **modificar datos de un paciente y darlo de baja lógica***, para* **mantener mi lista de trabajo limpia sin perder el historial clínico acumulado.** |
| **Criterios de Aceptación** Given: selecciono un paciente.  When: modifico su teléfono.  Then: updatedAt se actualiza y los cambios sincronizan con iCloud. Given: selecciono "Dar de baja" en un paciente.  When: confirmo en el diálogo.  Then: deletedAt se establece con la fecha actual; el paciente desaparece de la lista principal (filtrada por \#Predicate { $0.deletedAt \== nil }); su historia clínica permanece íntegra en CloudKit. Given: necesito consultar un paciente inactivo.  When: activo el filtro "Inactivos".  Then: el paciente aparece con etiqueta visual indicando la fecha de baja. |

| HU-04 — Documentación de Sesión y Diagnóstico CIE-11 |
| :---- |
| *Como* **profesional***, quiero* **registrar una sesión con notas clínicas y diagnósticos CIE-11 estandarizados***, para que* **la historia clínica sea completa, precisa e internacionalmente comparable.** |
| **Criterios de Aceptación** Given: estoy en el perfil de un paciente activo.  When: creo una sesión con motivo, notas y plan.  Then: la sesión queda guardada con fecha, hora y duración, vinculada al paciente. Given: estoy redactando una sesión.  When: busco "depresión" en el buscador CIE-11.  Then: la app consulta la API OAuth2, muestra código \+ descripción; al seleccionar, los datos se persisten como snapshot en SwiftData. Given: estoy sin internet.  When: abro un diagnóstico previamente registrado.  Then: el diagnóstico es legible con código y descripción completos, sin llamada a la API externa. |

| HU-05 — Visualización de Historia Clínica |
| :---- |
| *Como* **profesional***, quiero* **acceder a la historia clínica completa y cronológica de un paciente***, para* **tener contexto clínico inmediato antes y durante una consulta, incluso sin conexión.** |
| **Criterios de Aceptación** Given: abro el perfil de un paciente.  When: navego a su historial.  Then: veo todas sus sesiones ordenadas cronológicamente (más reciente primero), cargadas 100% desde SwiftData local (sin llamadas de red). Given: tengo múltiples pacientes.  When: uso el buscador de la lista principal.  Then: la búsqueda por nombre filtra en tiempo real con \#Predicate, sin latencia de red. |

# **4\. Lógica de Negocio — API CIE-11**

## **4.1 Arquitectura de la Integración**

La API del CIE-11 requiere autenticación OAuth 2.0 con Client Credentials. El flujo completo es:

| Paso | Acción | Endpoint / Detalle |
| :---- | :---- | :---- |
| 1 | Solicitar token OAuth2 | POST https://icdaccessmanagement.who.int/connect/token |
| 2 | Cachear token (\~1 hora TTL) | El ICD11Service (actor) gestiona el ciclo de vida del token. |
| 3 | Búsqueda con Bearer Token | GET https://id.who.int/icd/release/11/{version}/mms/search?q={query} |
| 4 | Headers obligatorios | Authorization: Bearer {token} | Accept-Language: es | API-Version: v2 |
| 5 | Persistir snapshot | Guardar código \+ título \+ URI \+ versión en entidad Diagnosis de SwiftData. |
| 6 | Lectura offline | El \#Predicate consulta SwiftData local. La API nunca se llama para historial. |

## **4.2 Estrategia Offline-First: Snapshot Inmutable**

| 💡  Principio rector: la historia clínica NUNCA debe depender de una API externa para ser legible. Los datos del CIE-11 se fotografían en el momento del diagnóstico. Es desnormalización intencional y correcta. |
| :---- |

| // Campos que se persisten en SwiftData al confirmar un diagnóstico. // Una vez guardados, son inmutables — representan la realidad clínica en ese momento. struct ICD11Snapshot: Codable, Sendable {     let code: String          // Ej: "6A70"     let title: String         // En el idioma del profesional al momento del dx     let titleEs: String       // Español (si disponible en la respuesta de la API)     let uri: String           // Ej: "http://id.who.int/icd/entity/..."     let releaseVersion: String // Ej: "2024-01" } // Actor que encapsula toda comunicación con la API del CIE-11. // @concurrent porque es I/O de red puro — no necesita MainActor. actor ICD11Service {     private var cachedToken: OAuthToken?     // Búsqueda en la linearización MMS (estándar clínico internacional)     @concurrent     func search(query: String, language: String \= "es") async throws \-\> \[ICD11SearchResult\] {         let token \= try await validToken()         // ... construcción de URLRequest con headers OAuth2 \+ Accept-Language         let (data, \_) \= try await URLSession.shared.data(for: request)         return try JSONDecoder().decode(\[ICD11SearchResult\].self, from: data)     }     // El token se renueva proactivamente antes de que expire.     // Esto evita el fallo de una búsqueda clínica por token vencido.     private func validToken() async throws \-\> String {         guard let token \= cachedToken, \!token.isExpired else {             let newToken \= try await fetchNewToken()             cachedToken \= newToken             return newToken.accessToken         }         return token.accessToken     } } |
| :---- |

## **4.3 Estrategia de Cache — Dos Niveles**

| Nivel | Tipo | TTL | Propósito |
| :---- | :---- | :---- | :---- |
| Nivel 1 | Cache en memoria (dentro del actor ICD11Service) | Sesión de usuario activa | Evitar llamadas duplicadas mientras el profesional navega resultados de búsqueda. |
| Nivel 2 | Snapshot en SwiftData (entidad Diagnosis) | Permanente e inmutable | Garantizar legibilidad histórica de la historia clínica sin internet y sin depender de la API. |

# **5\. Tabla Comparativa de Especificaciones**

Resumen de todos los ajustes al stack tecnológico derivados de la investigación pre-proyecto.

| Área | Especificación Original | Especificación Actualizada | Razón |
| :---- | :---- | :---- | :---- |
| Concurrencia | Swift 6.2 Strict Concurrency | Approachable Concurrency (-default-isolation MainActor) | El modo strict puro genera fricción innecesaria; el nuevo paradigma es igualmente seguro y más productivo. |
| Paralelismo | Sin mención explícita | @concurrent en ICD11Service y operaciones I/O pesadas | Opt-in explícito para paralelismo real fuera del MainActor. |
| Background SwiftData | Sin mención explícita | @ModelActor obligatorio para operaciones en background | Previene data races en Swift 6 al procesar lotes de datos clínicos. |
| Model Inheritance | Sin mención | @Model con herencia (iOS 26\) disponible para Professional | Nuevo en iOS 26; útil para futuras especializaciones por especialidad médica. |
| Diseño Visual | SwiftUI puro | SwiftUI puro \+ lenguaje visual Liquid Glass de iOS 26 | Es el nuevo estándar del sistema en iOS 26\. No usar hacks visuales anteriores. |
| CIE-11 Auth | async/await genérico | OAuth 2.0 Client Credentials \+ cache de token activo | La API del WHO requiere token renovable. El cache evita fallos durante consultas. |
| CIE-11 Endpoint | Sin especificar | Linearización MMS, API v2, Accept-Language: es | MMS es la linearización correcta para diagnósticos clínicos. |
| Deuda Técnica | Sin documentar | Posible migración a Core Data \+ CK Sharing en v2 | La comunidad reporta que casos complejos superan las capacidades actuales de SwiftData. |

*AMD — Documento de Arquitectura v1.0  ·  Confidencial  ·  Febrero 2026*