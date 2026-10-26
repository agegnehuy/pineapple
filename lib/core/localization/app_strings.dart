import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppStrings {
  const AppStrings(this.language);
  final String language;
  static const LocalizationsDelegate<AppStrings> delegate = _StringsDelegate();
  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      const AppStrings('en');
  static String tr(BuildContext context, String value) =>
      of(context).text(value);
  static String? error(BuildContext context, String? value) =>
      value == null ? null : tr(context, value);

  String text(String value) {
    if (language != 'fr') return value;
    final exact = french[value];
    if (exact != null) return exact;
    final lower = _lowerFrench[value.toLowerCase()];
    if (lower != null) return lower;
    for (final prefix in const {
      'Final grade: ': 'Note finale : ',
      'Missing information: ': 'Renseignements manquants : ',
      'Next steps: ': 'Prochaines étapes : ',
      'Weighted GPA: ': 'Moyenne pondérée : ',
      'Replaces: ': 'Remplace : ',
    }.entries) {
      if (value.startsWith(prefix.key)) {
        return prefix.value + value.substring(prefix.key.length);
      }
    }
    final profile = RegExp(
      r'^Your story is (\d+)% complete\.$',
    ).firstMatch(value);
    if (profile != null) {
      return 'Votre récit est complété à ${profile[1]!} %.';
    }
    final shaped = RegExp(
      r'^(\d+) opportunities shaped around your profile\.$',
    ).firstMatch(value);
    if (shaped != null) {
      return '${shaped[1]!} possibilités adaptées à votre profil.';
    }
    final results = RegExp(r'^(\d+) results shown$').firstMatch(value);
    if (results != null) {
      return results[1]! +
          (results[1] == '1' ? ' résultat affiché' : ' résultats affichés');
    }
    final show = RegExp(r'^Show (\d+) opportunities$').firstMatch(value);
    if (show != null) {
      return 'Afficher ${show[1]!}${show[1] == '1' ? ' possibilité' : ' possibilités'}';
    }
    final step = RegExp(
      r'^Set up your profile · (\d+) of (\d+)$',
    ).firstMatch(value);
    if (step != null) {
      return 'Configurez votre profil · ${step[1]!} sur ${step[2]!}';
    }
    final credits = RegExp(r'^([\d.,]+) credits$').firstMatch(value);
    if (credits != null) return '${credits[1]!} crédits';
    final courses = RegExp(
      r'^(\d+) courses · Default 4.0 scale$',
    ).firstMatch(value);
    if (courses != null) {
      return '${courses[1]!} cours · Échelle de 4,0 par défaut';
    }
    final messages = RegExp(r'^(\d+) AI messages remaining$').firstMatch(value);
    if (messages != null) {
      return messages[1]! +
          (messages[1] == '1'
              ? ' message IA restant'
              : ' messages IA restants');
    }
    final likes = RegExp(r'^(\d+) likes$').firstMatch(value);
    if (likes != null) return '${likes[1]} mentions J’aime';
    final removed = RegExp(r'^Remove course (\d+)$').firstMatch(value);
    if (removed != null) return 'Retirer le cours ${removed[1]!}';
    final status = RegExp(r'^Application marked (.+)\.$').firstMatch(value);
    if (status != null) {
      return 'Statut de la candidature : ${text(status[1]!)}.';
    }
    final greeting = RegExp(r'^A little closer, (.+)\.$').firstMatch(value);
    if (greeting != null) return 'Un peu plus près, ${greeting[1]!}.';
    final match = RegExp(r'^(\d+)% match$').firstMatch(value);
    if (match != null) return '${match[1]!} % de compatibilité';
    final count = RegExp(
      r'^(\d+) (matches|opportunities|courses|credits|assessments|goals)$',
    ).firstMatch(value);
    if (count != null) {
      const nouns = {
        'matches': 'recommandations',
        'opportunities': 'possibilités',
        'courses': 'cours',
        'credits': 'crédits',
        'assessments': 'évaluations',
        'goals': 'objectifs',
      };
      final noun = nouns[count[2]]!;
      return '${count[1]!} ${count[1] == '1' && noun != 'cours' ? noun.substring(0, noun.length - 1) : noun}';
    }
    final number = RegExp(
      r'^Enter a number from (.+) to (.+)\.$',
    ).firstMatch(value);
    if (number != null) {
      return 'Saisissez un nombre de ${number[1]!} à ${number[2]!}.';
    }
    for (final prefix in ['Enter ', 'Choose ']) {
      if (value.startsWith(prefix) && value.endsWith('.')) {
        final field = value.substring(prefix.length, value.length - 1);
        return '${prefix == 'Enter ' ? 'Veuillez saisir : ' : 'Veuillez choisir : '}${text(field)}.';
      }
    }
    return value;
  }

  static const french = <String, String>{
    'Résumé': 'CV',
    'Close': 'Fermer',
    'Your résumé': 'Votre CV',
    'The saved résumé could not be downloaded safely. Please upload it again.':
        'Impossible de télécharger le CV enregistré de façon sécurisée. Téléversez-le à nouveau.',
    'Choose a PDF or .docx résumé.': 'Choisissez un CV au format PDF ou DOCX.',
    'The saved résumé is empty. Please upload it again.':
        'Le CV enregistré est vide. Téléversez-le à nouveau.',
    'The downloaded file is too large.':
        'Le fichier téléchargé est trop volumineux.',
    'Your experience, ready to share.':
        'Votre expérience, prête à être partagée.',
    'Save a PDF or DOCX up to 4 MB to your profile. You choose when to share it.':
        'Enregistrez un PDF ou DOCX de 4 Mo maximum dans votre profil. Vous choisissez quand le partager.',
    'No résumé saved yet': 'Aucun CV enregistré',
    'Saved résumé': 'CV enregistré',
    'Keep your experience close for your next opportunity.':
        'Gardez votre expérience à portée de main pour votre prochaine possibilité.',
    'Save a copy': 'Enregistrer une copie',
    'Remove résumé': 'Supprimer le CV',
    'Choose a résumé': 'Choisir un CV',
    'Choose replacement': 'Choisir un autre fichier',
    'Review before you save': 'Vérifier avant d’enregistrer',
    'Save résumé': 'Enregistrer le CV',
    'Replace saved résumé?': 'Remplacer le CV enregistré?',
    'Your current résumé will be replaced by this file.':
        'Ce fichier remplacera votre CV actuel.',
    'Replace résumé': 'Remplacer le CV',
    'Résumé saved': 'CV enregistré',
    'Copy saved to your chosen location.':
        'Copie enregistrée à l’emplacement choisi.',
    'Remove saved résumé?': 'Supprimer le CV enregistré?',
    'This removes the résumé from your profile. Copies you downloaded stay on your device.':
        'Le CV sera supprimé de votre profil. Les copies téléchargées restent sur votre appareil.',
    'Résumé removed': 'CV supprimé',
    'Discard selected file?': 'Abandonner le fichier choisi?',
    'This file has not been saved to your profile.':
        'Ce fichier n’a pas été enregistré dans votre profil.',
    'Saving here does not submit an application or send your résumé to a provider.':
        'Enregistrer ici ne soumet pas de candidature et n’envoie pas votre CV à un organisme.',
    'Save, replace or download your résumé':
        'Enregistrer, remplacer ou télécharger votre CV',
    'Could not update your résumé. Please try again.':
        'Impossible de modifier votre CV. Réessayez.',
    'Choose a PDF or DOCX résumé.': 'Choisissez un CV au format PDF ou DOCX.',
    'Could not save this file. Please try again.':
        'Impossible d’enregistrer ce fichier. Réessayez.',
    'File export is unavailable on this device.':
        'L’exportation de fichiers n’est pas disponible sur cet appareil.',
    'Why this fits you': 'Pourquoi cela vous correspond',
    'Make your next chapter count.':
        'Donnez du sens à votre prochain chapitre.',
    'Varies': 'Variable',
    'Your applications.': 'Vos candidatures.',
    'Your shortlist, ready when you are.':
        'Votre sélection, prête quand vous le serez.',
    'A little progress goes a long way.': 'Chaque petit progrès compte.',
    'All saved': 'Toutes les possibilités enregistrées',
    'No saved opportunities closing soon':
        'Aucune échéance proche dans votre sélection',
    'Saved opportunities with a deadline in the next seven days will appear here.':
        'Les possibilités enregistrées dont l’échéance arrive dans les sept prochains jours apparaîtront ici.',
    'Saved here doesn’t mean applied. Your tracker keeps the next steps clear.':
        'Enregistrer ici ne signifie pas avoir postulé. Votre suivi précise les prochaines étapes.',
    'Continue application': 'Continuer la candidature',
    'How’s it going?': 'Comment cela avance-t-il?',
    'Save status': 'Enregistrer le statut',
    'You can change this whenever things move.':
        'Vous pouvez modifier ce statut au fil de vos progrès.',
    'Your session changed. Please try again.':
        'Votre session a changé. Veuillez réessayer.',
    'Saved calculations do not change your courses or profile.':
        'Les calculs enregistrés ne modifient ni vos cours ni votre profil.',
    'Estimates only. Confirm the official scale with your institution.':
        'Estimations seulement. Confirmez l’échelle officielle auprès de votre établissement.',
    'A clearer comparison.': 'Une comparaison plus claire.',
    'Convert between grading scales.':
        'Convertissez entre les échelles de notation.',
    'Percentage · 100-point scale': 'Pourcentage · échelle de 100 points',
    'Your grade (%)': 'Votre note (%)',
    'Convert grade': 'Convertir la note',
    'Enter a percentage from 0 to 100.': 'Saisissez un pourcentage de 0 à 100.',
    'Conversions vary by institution. Always confirm the official scale.':
        'Les conversions varient selon l’établissement. Confirmez toujours l’échelle officielle.',
    'Calculator': 'Calculateur',
    'Converter': 'Convertisseur',
    'See what’s possible.': 'Voyez les possibilités.',
    'Explore your next semester.': 'Explorez votre prochain semestre.',
    'Grading scale': 'Échelle de notation',
    'Grade (% or letter)': 'Note (% ou lettre)',
    'Enter a course name.': 'Saisissez le nom du cours.',
    'Enter a percentage from 0 to 100 or a letter grade on this scale.':
        'Saisissez un pourcentage de 0 à 100 ou une lettre de cette échelle.',
    'ESTIMATED GPA': 'MOYENNE ESTIMÉE',
    'Save calculation': 'Enregistrer le calcul',
    'GPA estimate': 'Estimation de la moyenne',
    'Saved calculations': 'Calculs enregistrés',
    'No saved calculations': 'Aucun calcul enregistré',
    'Save an estimate from the calculator to find it here.':
        'Enregistrez une estimation du calculateur pour la retrouver ici.',
    'Delete calculation': 'Supprimer le calcul',
    'Delete calculation?': 'Supprimer le calcul?',
    'This removes the saved result from your account.':
        'Cette action supprime le résultat enregistré de votre compte.',
    'Your calculation has not been saved.':
        'Votre calcul n’a pas été enregistré.',
    'These are estimates using website grading scales. Confirm official equivalencies with your institution. Saved calculations do not change your courses or profile.':
        'Ces estimations utilisent les échelles du site Web. Confirmez les équivalences officielles auprès de votre établissement. Les calculs enregistrés ne modifient ni vos cours ni votre profil.',
    'No grading scales available': 'Aucune échelle de notation disponible',
    'Try again when your connection is available.':
        'Réessayez lorsque votre connexion sera disponible.',
    'A course grade is unavailable on this scale. Choose another scale or remove that course.':
        'Une note de cours n’existe pas dans cette échelle. Choisissez une autre échelle ou retirez ce cours.',
    'From scale': 'Échelle de départ',
    'To scale': 'Échelle cible',
    'Current GPA': 'Moyenne actuelle',
    'Convert GPA': 'Convertir la moyenne',
    'Enter a GPA within the selected source scale.':
        'Saisissez une moyenne comprise dans l’échelle de départ choisie.',
    'This proportional estimate is not an official institutional equivalency.':
        'Cette estimation proportionnelle n’est pas une équivalence officielle de votre établissement.',
    'of course': 'du cours',
    'Not graded': 'Non noté',
    "Missing information": "Renseignements manquants",
    "Next steps": "Prochaines étapes",
    "Credit": "Crédit",
    "No grade": "Aucune note",
    "Credits planned": "Crédits prévus",
    "Provider and community content stays in its original language.":
        "Les contenus des organismes et de la communauté conservent leur langue d’origine.",
    "A request already exists between you.":
        "Une demande existe déjà entre vous.",
    "Add your academic and interest details to unlock personalized matches.":
        "Ajoutez vos études et vos intérêts pour recevoir des recommandations personnalisées.",
    "Add your personal details": "Ajoutez vos renseignements personnels",
    "AI is currently unavailable. The server provided the guidance below.":
        "L’IA est indisponible pour le moment. Le service a fourni les conseils ci-dessous.",
    "Applications in this stage will appear here.":
        "Les candidatures à cette étape apparaîtront ici.",
    "Apply this field": "Appliquer ce champ",
    "Apply this suggestion?": "Appliquer cette suggestion?",
    "Billing is unavailable. Please try again.":
        "La facturation est indisponible. Veuillez réessayer.",
    "Change this deadline’s completion status?":
        "Modifier l’état d’avancement de cette échéance?",
    "Coffee chat request sent.": "Demande de rencontre-café envoyée.",
    "Complete your profile": "Complétez votre profil",
    "Could not attach this document. Please try again.":
        "Impossible de joindre ce document. Veuillez réessayer.",
    "Could not complete that action. Please try again.":
        "Impossible d’effectuer cette action. Veuillez réessayer.",
    "Could not get a response. Your question is still here.":
        "Impossible d’obtenir une réponse. Votre question est conservée.",
    "Could not load history.": "Impossible de charger l’historique.",
    "Could not read this file. Try pasting its text instead.":
        "Impossible de lire ce fichier. Essayez d’en coller le texte.",
    "Could not read your profile text. Please try again.":
        "Impossible de lire le texte de votre profil. Veuillez réessayer.",
    "Could not save this field. Try again.":
        "Impossible d’enregistrer ce champ. Réessayez.",
    "Could not save your preference. Try again.":
        "Impossible d’enregistrer votre préférence. Réessayez.",
    "Could not save your profile. Please try again.":
        "Impossible d’enregistrer votre profil. Veuillez réessayer.",
    "Could not send the reset link. Please try again.":
        "Impossible d’envoyer le lien de réinitialisation. Veuillez réessayer.",
    "Could not update the application. Please try again.":
        "Impossible de mettre à jour la candidature. Veuillez réessayer.",
    "Could not update this application. Please try again.":
        "Impossible de mettre à jour cette candidature. Veuillez réessayer.",
    "Delete deadline?": "Supprimer l’échéance?",
    "Describe the issue with this content. Support will receive its reference along with your message.":
        "Décrivez le problème avec ce contenu. Le soutien recevra sa référence avec votre message.",
    "Drafting is unavailable. Your saved work is unchanged.":
        "La rédaction est indisponible. Votre travail enregistré reste inchangé.",
    "Drafting is unavailable. Your story is unchanged.":
        "La rédaction est indisponible. Votre récit reste inchangé.",
    "Edit assessment": "Modifier l’évaluation",
    "Edit degree plan": "Modifier le plan de diplôme",
    "Edit goal": "Modifier l’objectif",
    "Enter a whole number.": "Saisissez un nombre entier.",
    "Enter your current account email.":
        "Saisissez le courriel actuel de votre compte.",
    "Mark complete": "Marquer comme terminé",
    "Mark incomplete": "Marquer comme non terminé",
    "No final grade recorded": "Aucune note finale enregistrée",
    "No matches yet": "Aucune recommandation pour le moment",
    "No opportunities fit your profile right now. Check again later or review your interests.":
        "Aucune possibilité ne correspond actuellement à votre profil. Revenez plus tard ou vérifiez vos intérêts.",
    "Open a match and start an application. It will appear here automatically.":
        "Ouvrez une recommandation et commencez une candidature. Elle apparaîtra ici automatiquement.",
    "Remove from this question": "Retirer de cette question",
    "Replace this profile field?": "Remplacer ce champ de profil?",
    "Review the opportunity details and begin your application when you are ready.":
        "Consultez les détails de la possibilité et commencez votre candidature lorsque vous le souhaitez.",
    "See details": "Voir les détails",
    "See listing": "Consulter l’annonce",
    "Set up degree plan": "Créer un plan de diplôme",
    "Start with where you are.": "Commençons par votre parcours.",
    "Tell us what matters to you": "Dites-nous ce qui compte pour vous",
    "This deadline will be removed.": "Cette échéance sera supprimée.",
    "Type DELETE exactly.": "Saisissez exactement DELETE.",
    "Update deadline?": "Mettre à jour l’échéance?",
    "We could not create your account. Please try again.":
        "Impossible de créer votre compte. Veuillez réessayer.",
    "We could not sign you in. Please try again.":
        "Impossible de vous connecter. Veuillez réessayer.",
    "What opens doors for you?": "Qu’est-ce qui vous ouvre des portes?",
    "Your message will be sent to the MyOccasio support team.":
        "Votre message sera envoyé à l’équipe de soutien MyOccasio.",
    "Your profile needs a little more detail before matching can begin.":
        "Ajoutez quelques détails à votre profil pour recevoir des recommandations.",
    "Optional": "Facultatif",
    "Student": "Membre étudiant",
    "Free": "Gratuit",
    "Academic": "Scolaire",
    "Scholarship": "Bourse",
    "Internship": "Stage",
    "Grant": "Subvention",
    "Job": "Emploi",
    "Personal development": "Développement personnel",
    "Not started": "Non commencé",
    "Assignment": "Travail",
    "Exam": "Examen",
    "Application": "Candidature",
    "Feed": "Fil",
    "Any time": "Toutes les dates",
    "This month": "Ce mois-ci",
    "Next month": "Le mois prochain",
    "New matches": "Nouvelles recommandations",
    "Deadline reminders": "Rappels d’échéance",
    "Application updates": "Suivi des candidatures",
    "Weekly roundup": "Récapitulatif hebdomadaire",
    "Help me understand the eligibility criteria and create an application checklist.":
        "Aidez-moi à comprendre les critères d’admissibilité et à préparer une liste de tâches pour ma candidature.",
    "Review my statement for clarity, evidence and alignment with the criteria. Ask for my statement if it is missing.":
        "Examinez mon texte pour améliorer sa clarté, ses exemples et son adéquation aux critères. Demandez-moi mon texte s’il est absent.",
    "Help me practise for an interview for this opportunity, one question at a time.":
        "Aidez-moi à préparer une entrevue pour cette possibilité, une question à la fois.",
    "Opportunity": "Possibilité",
    "Provider description": "Description de l’organisme",
    "My current statement": "Mon texte actuel",
    "Use only supplied facts. Ask me for missing information.":
        "Utilisez seulement les faits fournis. Demandez-moi les renseignements manquants.",
    "Delete my account": "Supprimer mon compte",
    "Check your inbox.": "Vérifiez votre boîte de réception.",
    "Let’s get you in.": "Retrouvons votre accès.",
    "Continue": "Continuer",
    "Saving…": "Enregistrement…",
    "Find my matches": "Voir mes recommandations",
    "Date unavailable": "Date indisponible",
    "Applied": "Appliqué",
    "Imported information": "Renseignement importé",
    "Current value": "Valeur actuelle",
    "Suggested value": "Valeur suggérée",
    "Empty": "Vide",
    "Shown for reference only.": "Affiché à titre de référence seulement.",
    "AI-generated draft. Review every fact and keep your own voice. Saving does not submit your application.":
        "Brouillon généré par l’IA. Vérifiez chaque fait et gardez votre voix. L’enregistrement ne soumet pas votre candidature.",
    "Choose at least one interest and opportunity type.":
        "Choisissez au moins un intérêt et un type de possibilité.",
    "Could not save. Your draft is still here. Please try again.":
        "Impossible d’enregistrer. Votre brouillon est conservé. Veuillez réessayer.",
    "Your profile could not be saved. Please try again.":
        "Impossible d’enregistrer votre profil. Veuillez réessayer.",
    "Connection timed out. Please try again.":
        "La connexion a expiré. Veuillez réessayer.",
    "Post comment": "Publier le commentaire",
    "A little closer.": "Un peu plus près.",
    "A strong match.\nA fresh start.":
        "Une belle correspondance.\nUn nouveau départ.",
    "Your next chapter\nstarts here.": "Votre prochain chapitre\ncommence ici.",
    "Keep the good ones.": "Gardez les belles possibilités.",
    "Your applications": "Vos candidatures",
    "Add at least one interest.": "Ajoutez au moins un intérêt.",
    "Add at least one opportunity type.":
        "Ajoutez au moins un type de possibilité.",
    "An open doorway to your next chapter":
        "Une porte ouverte vers votre prochain chapitre",
    "At least 8 characters": "Au moins 8 caractères",
    "Choose your citizenship status.":
        "Choisissez votre statut de citoyenneté.",
    "Choose your residency.": "Choisissez votre statut de résidence.",
    "Choose your year.": "Choisissez votre année d’études.",
    "Could not save your language. Please try again.":
        "Impossible d’enregistrer votre langue. Veuillez réessayer.",
    "Document": "Document",
    "Enter your password.": "Saisissez votre mot de passe.",
    "Enter your program.": "Saisissez votre programme.",
    "Enter your school.": "Saisissez votre établissement.",
    "Finding your strongest matches…":
        "Recherche de vos meilleures recommandations…",
    "Loading your applications…": "Chargement de vos candidatures…",
    "Loading your profile…": "Chargement de votre profil…",
    "Preparing your dashboard…": "Préparation de votre tableau de bord…",
    "Program or field of study": "Programme ou domaine d’études",
    "Requesting reset link": "Demande du lien de réinitialisation",
    "Required": "Obligatoire",
    "Saving opportunity": "Enregistrement de la possibilité",
    "Updating application": "Mise à jour de la candidature",
    "Use at least 8 characters.": "Utilisez au moins 8 caractères.",
    "Value": "Valeur",
    "Waiting for response": "En attente d’une réponse",
    "Show password": "Afficher le mot de passe",
    "Hide password": "Masquer le mot de passe",
    "Canadian citizen": "Citoyenneté canadienne",
    "Permanent resident": "Résidence permanente",
    "International student": "Étudiant international",
    "Refugee": "Réfugié",
    "Other": "Autre",
    "High school": "Secondaire",
    "1st year": "1re année",
    "2nd year": "2e année",
    "3rd year": "3e année",
    "4th year": "4e année",
    "5+ year": "5e année ou plus",
    "Graduate": "Cycles supérieurs",
    "Science & Technology": "Sciences et technologie",
    "Engineering": "Génie",
    "Computer Science": "Informatique",
    "Artificial Intelligence & Data": "Intelligence artificielle et données",
    "Business": "Affaires",
    "Finance": "Finance",
    "Economics": "Économie",
    "Arts & Design": "Arts et design",
    "Humanities": "Sciences humaines",
    "Social Sciences": "Sciences sociales",
    "Health & Medicine": "Santé et médecine",
    "Mental Health & Wellness": "Santé mentale et bien-être",
    "Law": "Droit",
    "Education": "Éducation",
    "Environment & Sustainability": "Environnement et développement durable",
    "Skilled Trades": "Métiers spécialisés",
    "Media & Communications": "Médias et communications",
    "Marketing & Sales": "Marketing et ventes",
    "Entrepreneurship": "Entrepreneuriat",
    "Research": "Recherche",
    "Government & Public Service": "Gouvernement et fonction publique",
    "International Affairs": "Affaires internationales",
    "Human Rights & Advocacy": "Droits de la personne et défense des droits",
    "Community & Social Impact": "Communauté et impact social",
    "Sports & Recreation": "Sports et loisirs",
    "Agriculture & Food": "Agriculture et alimentation",
    "Hospitality & Tourism": "Hôtellerie et tourisme",
    "Architecture & Urban Planning": "Architecture et urbanisme",
    "Transportation & Logistics": "Transport et logistique",
    "Energy & Natural Resources": "Énergie et ressources naturelles",
    "What motivates you": "Ce qui vous motive",
    "What you’re proud of": "Ce dont vous êtes fier",
    "Academic interests": "Intérêts scolaires",
    "Career interests": "Intérêts professionnels",
    "Keep private from AI": "Ne pas partager avec l’IA",
    "Allow use in AI guidance": "Autoriser l’utilisation par l’IA",
    "Planned": "Prévu",
    "Completed": "Terminé",
    "Learning": "Apprentissage",
    "Personal": "Personnel",
    "Career": "Carrière",
    "Health": "Santé",
    "Choose your language and display settings. Your choices are saved on this device.":
        "Choisissez votre langue et vos paramètres d’affichage. Vos choix sont enregistrés sur cet appareil.",
    "Filters": "Filtres",
    "Filters applied": "Filtres appliqués",
    "Complete profile": "Compléter le profil",
    "Add details": "Ajouter des renseignements",
    "You": "Vous",
    "Your workspace": "Votre espace",
    "A conversation can help.": "Une conversation peut aider.",
    "Make room for connection.": "Faites place aux rencontres.",
    "Find your people.": "Trouvez votre communauté.",
    "Coffee chats begin with a request. Only share contact details when ready.":
        "Les rencontres-café commencent par une demande. Partagez vos coordonnées seulement lorsque vous le souhaitez.",
    "Event times below use your device’s local time zone.":
        "Les heures ci-dessous utilisent le fuseau horaire de votre appareil.",
    "Be kind. Share experiences, and keep private information private.":
        "Faites preuve de bienveillance. Partagez vos expériences et protégez les renseignements privés.",
    "Share a win": "Partager une réussite",
    "Create a post": "Créer une publication",
    "Publish": "Publier",
    "Register for event": "S’inscrire à l’événement",
    "Cancel registration": "Annuler l’inscription",
    "Registration cancelled.": "Inscription annulée.",
    "You’re registered.": "Votre inscription est confirmée.",
    "Draft · Not submitted": "Brouillon · Non soumis",
    "Submitting…": "Envoi…",
    "Submit your application?": "Soumettre votre candidature?",
    "Confirm submission": "Confirmer l’envoi",
    "Withdraw": "Retirer",
    "Withdraw application?": "Retirer la candidature?",
    "Application submitted.": "Candidature soumise.",
    "Application withdrawn.": "Candidature retirée.",
    "The provider will see that you withdrew your application.":
        "L’organisme verra que vous avez retiré votre candidature.",
    "Your saved statement and profile snapshot will be sent to the provider. Review them before continuing.":
        "Votre texte enregistré et un aperçu de votre profil seront transmis à l’organisme. Vérifiez-les avant de continuer.",
    "Under review": "En cours d’examen",
    "Shortlisted": "Présélectionnée",
    "Declined": "Refusée",
    "Withdrawn": "Retirée",
    "Turn requirements into a checklist.":
        "Transformez les exigences en liste de tâches.",
    "Get feedback on clarity and examples.":
        "Obtenez des conseils sur la clarté et les exemples.",
    "Practise with prompts and feedback.":
        "Exercez-vous avec des questions et des commentaires.",
    "Opportunity saved": "Possibilité enregistrée",
    "A little guidance.": "Un peu de soutien.",
    "A little help goes a long way.": "Un peu d’aide peut tout changer.",
    "A practical plan for a stronger application.":
        "Un plan concret pour une candidature plus solide.",
    "About the opportunity": "À propos de cette possibilité",
    "Academics": "Études",
    "Accessibility": "Accessibilité",
    "Accessibility support": "Aide à l’accessibilité",
    "Account email": "Courriel du compte",
    "Active": "Actives",
    "Add a comment": "Ajouter un commentaire",
    "Add a course to track your grades and credits.":
        "Ajoutez un cours pour suivre vos notes et vos crédits.",
    "Add a statement to prepare your application.":
        "Ajoutez un texte de présentation pour préparer votre candidature.",
    "Add assessment": "Ajouter une évaluation",
    "Add assessments to track the work behind your grade.":
        "Ajoutez des évaluations pour suivre les travaux qui composent votre note.",
    "Add course": "Ajouter un cours",
    "Add deadline": "Ajouter une échéance",
    "Add statement": "Ajouter un texte",
    "Add to calculation": "Ajouter au calcul",
    "Add your next deadline to plan ahead.":
        "Ajoutez votre prochaine échéance pour mieux planifier.",
    "Added to your applications.": "Ajoutée à vos candidatures.",
    "AI-generated draft. Check accuracy and keep your own voice. This has not been saved or submitted.":
        "Brouillon généré par l’IA. Vérifiez les faits et conservez votre voix. Il n’a été ni enregistré ni soumis.",
    "AI support · Check important details":
        "Soutien IA · Vérifiez les détails importants",
    "All": "Toutes",
    "All locations": "Tous les lieux",
    "Allow financial context in AI guidance":
        "Autoriser le contexte financier dans les conseils de l’IA",
    "Allow this draft to use my account profile and saved story. Financial context follows my story privacy choice.":
        "Autoriser ce brouillon à utiliser mon profil et mon récit enregistrés. Le contexte financier respecte le choix de confidentialité de mon récit.",
    "Already a member? Sign in": "Déjà membre? Connectez-vous",
    "Appearance": "Apparence",
    "Application coach": "Accompagnement de candidature",
    "Application workspace": "Espace de candidature",
    "Applications": "Candidatures",
    "Applications unavailable": "Candidatures indisponibles",
    "Apply": "Appliquer",
    "Ask a question…": "Posez une question…",
    "Ask about an opportunity, your story, or your next application step. AI guidance can use your saved profile when enabled.":
        "Posez une question sur une possibilité, votre récit ou la prochaine étape de candidature. L’IA peut utiliser votre profil enregistré si vous l’autorisez.",
    "Assessment name": "Nom de l’évaluation",
    "Assessments": "Évaluations",
    "Attach document": "Joindre un document",
    "Attachments are uploaded to your account and included with your question.":
        "Les pièces jointes sont téléversées dans votre compte et incluses avec votre question.",
    "Awarded": "Obtenue",
    "Back": "Retour",
    "Back to education": "Retour aux études",
    "Back to sign in": "Retour à la connexion",
    "Be the first to join the conversation.": "Lancez la conversation.",
    "Best match": "Meilleure compatibilité",
    "By creating an account, you agree to the Terms of Service and Privacy Policy.":
        "En créant un compte, vous acceptez les conditions d’utilisation et la politique de confidentialité.",
    "Cancel": "Annuler",
    "Category": "Catégorie",
    "Change application status": "Modifier le statut de candidature",
    "Check your connection and try again.":
        "Vérifiez votre connexion et réessayez.",
    "Choose résumé file · up to 4 MB": "Choisir un CV · 4 Mo maximum",
    "Choose the notes to send to the AI service for this request. Generation uses your AI allowance. Review and edit the result before saving; it will not submit an application.":
        "Choisissez les notes à transmettre au service d’IA pour cette demande. La génération utilise votre quota d’IA. Relisez et modifiez le résultat avant de l’enregistrer; aucune candidature ne sera soumise.",
    "Choose where to begin": "Choisissez par où commencer",
    "Choose your display settings. Your selection is saved on this device.":
        "Choisissez vos paramètres d’affichage. Votre choix est enregistré sur cet appareil.",
    "Citizenship or residency": "Citoyenneté ou résidence",
    "Citizenship status": "Statut de citoyenneté",
    "Close filters": "Fermer les filtres",
    "Close menu": "Fermer le menu",
    "Closing soon": "Échéance proche",
    "Coach": "Conseils",
    "Coffee chats": "Rencontres-café",
    "Community": "Communauté",
    "Community activity": "Activité communautaire",
    "Consent & generate": "Autoriser et générer",
    "Contact support": "Contacter le soutien",
    "Conversation": "Conversation",
    "Could not clear your session. Please try again.":
        "Impossible d’effacer votre session. Veuillez réessayer.",
    "Could not clear your session. Please try signing out again.":
        "Impossible d’effacer votre session. Essayez de vous déconnecter à nouveau.",
    "Could not complete this action. Please try again.":
        "Impossible d’effectuer cette action. Veuillez réessayer.",
    "Could not connect. Check your connection and try again.":
        "Connexion impossible. Vérifiez votre connexion et réessayez.",
    "Could not load this page": "Impossible de charger cette page",
    "Could not open this link. Please try again with a browser installed.":
        "Impossible d’ouvrir ce lien. Réessayez avec un navigateur installé.",
    "Could not save this application. Try again.":
        "Impossible d’enregistrer cette candidature. Réessayez.",
    "Could not save this opportunity.":
        "Impossible d’enregistrer cette possibilité.",
    "Could not save this opportunity. Please try again.":
        "Impossible d’enregistrer cette possibilité. Veuillez réessayer.",
    "Could not save your display setting. Please try again.":
        "Impossible d’enregistrer votre choix d’affichage. Veuillez réessayer.",
    "Course code": "Code du cours",
    "Course credits": "Crédits du cours",
    "Course detail": "Détails du cours",
    "Course name": "Nom du cours",
    "Course unavailable": "Cours indisponible",
    "Courses & grades": "Cours et notes",
    "Create account": "Créer un compte",
    "Create my account": "Créer mon compte",
    "Credits": "Crédits",
    "Credits per term": "Crédits par trimestre",
    "CURRENT GPA": "MOYENNE ACTUELLE",
    "Dark": "Sombre",
    "Deadline": "Échéance",
    "Deadline actions": "Actions de l’échéance",
    "Degree name": "Nom du diplôme",
    "Degree plan": "Plan de diplôme",
    "Delete": "Supprimer",
    "Delete account": "Supprimer le compte",
    "Delete assessment": "Supprimer l’évaluation",
    "Delete assessment?": "Supprimer l’évaluation?",
    "Delete course": "Supprimer le cours",
    "Delete goal?": "Supprimer l’objectif?",
    "Delete this course?": "Supprimer ce cours?",
    "Description": "Description",
    "Discard": "Abandonner",
    "Discard changes": "Abandonner les modifications",
    "Discard unsaved changes?":
        "Abandonner les modifications non enregistrées?",
    "Discover": "Découvrir",
    "Document attachments are not supported by this application endpoint. Check the provider’s requirements before submitting.":
        "L’envoi de documents n’est pas pris en charge pour cette candidature. Vérifiez les exigences de l’organisme avant de la soumettre.",
    "Draft a personal statement": "Rédiger un texte de présentation",
    "Draft from your story": "Rédiger à partir de votre récit",
    "Due date (YYYY-MM-DD)": "Date d’échéance (AAAA-MM-JJ)",
    "Due soon": "À venir",
    "Edit": "Modifier",
    "Edit course": "Modifier le cours",
    "Edit my story": "Modifier mon récit",
    "Edit profile": "Modifier le profil",
    "Edit statement": "Modifier le texte",
    "Email address": "Adresse courriel",
    "Email is shown for comparison only.":
        "Le courriel est affiché uniquement à titre de comparaison.",
    "English": "English",
    "Enter a valid email address.": "Saisissez une adresse courriel valide.",
    "Enter at least two characters.": "Saisissez au moins deux caractères.",
    "Estimate using the website’s default 4.0 scale. Your institution’s official conversion may differ. These calculations do not change your saved courses.":
        "Estimation selon l’échelle de 4,0 par défaut du site. La conversion officielle de votre établissement peut différer. Ces calculs ne modifient pas vos cours enregistrés.",
    "Events": "Événements",
    "Expected graduation": "Date de diplomation prévue",
    "Feel at home here.": "Sentez-vous chez vous.",
    "Financial context": "Contexte financier",
    "Financial context (optional)": "Contexte financier (facultatif)",
    "Financial need": "Besoin financier",
    "Find my opportunities": "Voir mes possibilités",
    "Find opportunities that fit your story.\nBuild the future you have in mind.":
        "Trouvez des possibilités qui correspondent à votre parcours.\nBâtissez l’avenir que vous imaginez.",
    "Find your fit.": "Trouvez votre voie.",
    "First name": "Prénom",
    "Forgot your password?": "Mot de passe oublié?",
    "Français": "Français",
    "General": "Général",
    "Generate draft for review": "Générer un brouillon à relire",
    "Generating draft…": "Génération du brouillon…",
    "Get help with your account, matching, or an application. Keep passwords and private documents out of your message.":
        "Obtenez de l’aide pour votre compte, vos recommandations ou une candidature. N’incluez ni mot de passe ni document confidentiel dans votre message.",
    "Get started": "Commencer",
    "Goal actions": "Actions de l’objectif",
    "Goal title": "Titre de l’objectif",
    "GPA": "Moyenne",
    "GPA calculator & converter": "Calcul et conversion de moyenne",
    "Grade (%)": "Note (%)",
    "Grants": "Subventions",
    "Help & support": "Aide et soutien",
    "History": "Historique",
    "Home": "Accueil",
    "How can we help?": "Comment pouvons-nous vous aider?",
    "If an account exists for this email, you’ll receive a secure reset link. Check your inbox and spam folder. The link expires in one hour.":
        "Si un compte est associé à ce courriel, vous recevrez un lien de réinitialisation sécurisé. Vérifiez votre boîte de réception et vos pourriels. Le lien expire dans une heure.",
    "Import profile": "Importer le profil",
    "In progress": "En cours",
    "Included with your subscription. Fair-use limits apply.":
        "Inclus dans votre abonnement. Des limites d’utilisation raisonnable s’appliquent.",
    "Institution": "Établissement",
    "Interests": "Intérêts",
    "Internships": "Stages",
    "Its assessments will also be removed. This cannot be undone.":
        "Ses évaluations seront aussi supprimées. Cette action est irréversible.",
    "Jobs": "Emplois",
    "Keep editing": "Continuer à modifier",
    "Keep every opportunity moving.": "Faites avancer chaque possibilité.",
    "Keep your changes?": "Conserver vos modifications?",
    "Language": "Langue",
    "Language and appearance": "Langue et apparence",
    "Large text and reduced motion follow your device accessibility settings.":
        "La taille du texte et les animations réduites suivent les réglages d’accessibilité de votre appareil.",
    "Last name": "Nom de famille",
    "Let’s find your fit.": "Trouvons votre voie.",
    "Light": "Clair",
    "Loading": "Chargement",
    "Loading…": "Chargement…",
    "Location": "Lieu",
    "Made for you": "Pour vous",
    "Make it yours": "À votre image",
    "Make it yours.": "À votre image.",
    "Make room for what matters": "Faites place à l’essentiel",
    "Make your case.": "Mettez vos atouts en valeur.",
    "Make your effort count.": "Faites compter vos efforts.",
    "Manage existing billing": "Gérer la facturation",
    "Match details are not available. Review the provider’s eligibility criteria before applying.":
        "Les détails de compatibilité ne sont pas disponibles. Consultez les critères d’admissibilité de l’organisme avant de postuler.",
    "Matches": "Offres",
    "Matches are taking a break": "Les recommandations font une pause",
    "More possibility.\nLess searching.":
        "Plus de possibilités.\nMoins de recherches.",
    "My profile": "Mon profil",
    "My story": "Mon récit",
    "New conversation": "Nouvelle conversation",
    "New to MyOccasio? Create account":
        "Nouveau sur MyOccasio? Créez un compte",
    "No": "Non",
    "No applications yet": "Aucune candidature pour le moment",
    "No profile fields were found. Try adding more detail, or edit your profile manually.":
        "Aucun champ de profil n’a été trouvé. Ajoutez des détails ou modifiez votre profil manuellement.",
    "No recent activity": "Aucune activité récente",
    "No results": "Aucun résultat",
    "No saved conversations yet": "Aucune conversation enregistrée",
    "Not selected": "Non retenue",
    "Notes": "Notes",
    "Nothing here yet": "Rien pour le moment",
    "Notification preferences": "Préférences de notification",
    "Notifications": "Notifications",
    "Notifications are not available in this app yet.":
        "Les notifications ne sont pas encore disponibles dans cette application.",
    "Open application": "Ouvrir la candidature",
    "Open doors.": "Ouvrez des portes.",
    "Open menu": "Ouvrir le menu",
    "Open provider website": "Ouvrir le site de l’organisme",
    "Opportunity saved.": "Possibilité enregistrée.",
    "Opportunity type": "Type de possibilité",
    "Opportunity types": "Types de possibilités",
    "Password": "Mot de passe",
    "Paste text from your résumé or LinkedIn export. Review every suggestion before applying it. Importing does not change your profile automatically.":
        "Collez le texte de votre CV ou de votre exportation LinkedIn. Vérifiez chaque suggestion avant de l’appliquer. L’importation ne modifie pas votre profil automatiquement.",
    "People": "Personnes",
    "Personal goals": "Objectifs personnels",
    "Personal statement": "Texte de présentation",
    "Picked for you": "Choisies pour vous",
    "Plan & AI allowance": "Forfait et quota d’IA",
    "Please add at least 10 characters.": "Ajoutez au moins 10 caractères.",
    "Please wait…": "Veuillez patienter…",
    "Prefer not to say": "Préfère ne pas répondre",
    "Prepare a draft": "Préparer un brouillon",
    "Prepare for an interview": "Préparer une entrevue",
    "Preparing draft…": "Préparation du brouillon…",
    "Privacy policy": "Politique de confidentialité",
    "Profile saved.": "Profil enregistré.",
    "Profile unavailable": "Profil indisponible",
    "Program of study": "Programme d’études",
    "Progress (%)": "Progression (%)",
    "Pull down to refresh and check again later.":
        "Faites glisser vers le bas pour actualiser et revenez plus tard.",
    "Questions are reviewed before sending. AI guidance does not guarantee selection or funding.":
        "Relisez vos questions avant de les envoyer. Les conseils de l’IA ne garantissent ni sélection ni financement.",
    "Recent activity": "Activité récente",
    "Refresh failed. Showing the last loaded information.":
        "Actualisation impossible. Les dernières données chargées sont affichées.",
    "Remove": "Retirer",
    "Remove from saved": "Retirer des éléments enregistrés",
    "Remove from saved?": "Retirer des éléments enregistrés?",
    "Report": "Signaler",
    "Report content to support": "Signaler du contenu au soutien",
    "Report this content": "Signaler ce contenu",
    "Request a coffee chat": "Demander une rencontre-café",
    "Request a coffee chat?": "Demander une rencontre-café?",
    "Reset calculation": "Réinitialiser le calcul",
    "Reset filters": "Réinitialiser les filtres",
    "Reset link requested": "Lien de réinitialisation demandé",
    "Résumé or profile text": "Texte du CV ou du profil",
    "Retry": "Réessayer",
    "Retry draft generation": "Réessayer la génération",
    "Review & submit": "Vérifier et soumettre",
    "Review application draft": "Relire le brouillon de candidature",
    "Review profile": "Vérifier le profil",
    "Review suggestions": "Vérifier les suggestions",
    "Review your draft": "Relire votre brouillon",
    "Room for your next step.": "Une place pour la prochaine étape.",
    "Save": "Enregistrer",
    "Save and leave": "Enregistrer et quitter",
    "Save opportunity": "Enregistrer la possibilité",
    "Save profile": "Enregistrer le profil",
    "Saved": "Enregistrée",
    "Saved conversation history is not included with your current plan.":
        "L’historique des conversations enregistrées n’est pas inclus dans votre forfait actuel.",
    "Saved conversations": "Conversations enregistrées",
    "Saved opportunities": "Possibilités enregistrées",
    "Saved personal statement": "Texte de présentation enregistré",
    "Saved successfully.": "Enregistrement réussi.",
    "Saving": "Enregistrement",
    "School or institution": "École ou établissement",
    "Scholarships": "Bourses",
    "Score (%)": "Résultat (%)",
    "Search opportunities": "Rechercher des possibilités",
    "See all": "Tout voir",
    "Select one": "Choisir une option",
    "Send message": "Envoyer le message",
    "Send question": "Envoyer la question",
    "Send request": "Envoyer la demande",
    "Send reset link": "Envoyer le lien",
    "Send this student a connection request? Only share personal contact details when you are ready.":
        "Envoyer une demande de connexion à cette personne? Partagez vos coordonnées seulement lorsque vous le souhaitez.",
    "Set a goal": "Définir un objectif",
    "Set a goal and track your progress.":
        "Définissez un objectif et suivez votre progression.",
    "Settings": "Paramètres",
    "Sign in": "Se connecter",
    "Sign out": "Se déconnecter",
    "Sign out?": "Se déconnecter?",
    "Signing out…": "Déconnexion…",
    "Small steps. Real progress.": "De petits pas. De vrais progrès.",
    "Start application": "Commencer la candidature",
    "Start with the basics. You can complete your matching profile next.":
        "Commençons par l’essentiel. Vous pourrez ensuite compléter votre profil de recommandations.",
    "Start with your experience.": "Partez de votre expérience.",
    "Statement": "Texte",
    "Status": "Statut",
    "Strengthen my statement": "Renforcer mon texte",
    "Study plan & deadlines": "Plan d’études et échéances",
    "Submitted": "Soumise",
    "Target date (YYYY-MM-DD)": "Date cible (AAAA-MM-JJ)",
    "Target GPA (4.0 scale)": "Moyenne cible (échelle de 4,0)",
    "Term": "Trimestre",
    "Terms of service": "Conditions d’utilisation",
    "There’s more to you.": "Vous avez tant à raconter.",
    "These preferences apply to your MyOccasio account. Device push notifications are separate.":
        "Ces préférences s’appliquent à votre compte MyOccasio. Les notifications poussées de l’appareil sont distinctes.",
    "This course may have been removed.": "Ce cours a peut-être été supprimé.",
    "This goal and its progress will be removed.":
        "Cet objectif et sa progression seront supprimés.",
    "This permanently deletes your account and owned data, and cancels active billing. Enter your account email and DELETE to confirm. This cannot be undone.":
        "Cette action supprime définitivement votre compte et ses données, et annule la facturation active. Saisissez le courriel du compte et DELETE pour confirmer. Cette action est irréversible.",
    "This provider accepts applications on its own site. Opening it does not submit or update your application status.":
        "Cet organisme reçoit les candidatures sur son propre site. L’ouvrir ne soumet pas votre candidature et ne modifie pas son statut.",
    "This removes the assessment from your course.":
        "Cette action retire l’évaluation de votre cours.",
    "Title": "Titre",
    "Total credits": "Crédits totaux",
    "Track your term, one course at a time.":
        "Suivez votre trimestre, un cours à la fois.",
    "Try a different search or opportunity type.":
        "Essayez une autre recherche ou un autre type de possibilité.",
    "Try again": "Réessayer",
    "Type DELETE": "Saisissez DELETE",
    "Understand the criteria": "Comprendre les critères",
    "Use a valid date in YYYY-MM-DD format.":
        "Utilisez une date valide au format AAAA-MM-JJ.",
    "Use another email": "Utiliser un autre courriel",
    "Use device setting": "Suivre l’appareil",
    "Use my profile": "Utiliser mon profil",
    "Use my saved opportunities": "Utiliser mes possibilités enregistrées",
    "Use your own voice. Save your draft before reviewing or submitting.":
        "Gardez votre voix. Enregistrez votre brouillon avant de le vérifier ou de le soumettre.",
    "Uses the existing application guidance service and your account allowance. Availability depends on your plan. You review the result before saving.":
        "Utilise le service d’accompagnement de candidature et le quota de votre compte. La disponibilité dépend de votre forfait. Vous relisez le résultat avant de l’enregistrer.",
    "View provider listing": "Voir l’annonce de l’organisme",
    "We could not load your opportunities right now.":
        "Impossible de charger vos possibilités pour le moment.",
    "We could not load your profile right now.":
        "Impossible de charger votre profil pour le moment.",
    "We could not load your saved applications.":
        "Impossible de charger vos candidatures enregistrées.",
    "We could not open your dashboard":
        "Impossible d’ouvrir votre tableau de bord",
    "We couldn’t restore your session": "Impossible de rétablir votre session",
    "We’ll send you a secure reset link. Use the email linked to your account.":
        "Nous vous enverrons un lien sécurisé. Utilisez le courriel associé à votre compte.",
    "Weight (%)": "Pondération (%)",
    "Welcome back.": "Heureux de vous revoir.",
    "What are you looking for?": "Que recherchez-vous?",
    "What should the draft focus on? (optional)":
        "Sur quoi le brouillon doit-il porter? (facultatif)",
    "What would you like to work on?": "Sur quoi souhaitez-vous travailler?",
    "What you want": "Vos objectifs",
    "What’s on your mind?": "Qu’avez-vous en tête?",
    "What’s your next step?": "Quelle est votre prochaine étape?",
    "Why this is you": "Pourquoi cela vous correspond",
    "Wins": "Réussites",
    "Withdraw application": "Retirer la candidature",
    "Year of study": "Année d’études",
    "Yes": "Oui",
    "You can sign back in at any time.":
        "Vous pouvez vous reconnecter à tout moment.",
    "You have edits that haven’t been saved. Save them before leaving this page.":
        "Certaines modifications ne sont pas enregistrées. Enregistrez-les avant de quitter cette page.",
    "Your academic life, in one place.":
        "Votre vie étudiante, au même endroit.",
    "Your account activity will appear here.":
        "L’activité de votre compte apparaîtra ici.",
    "Your AI companion for the next step.":
        "Votre allié IA pour la prochaine étape.",
    "Your background": "Votre parcours",
    "Your basics": "Vos renseignements",
    "Your changes have not been saved.":
        "Vos modifications n’ont pas été enregistrées.",
    "Your comment": "Votre commentaire",
    "Your community involvement": "Votre engagement communautaire",
    "Your experiences can open doors.":
        "Vos expériences peuvent ouvrir des portes.",
    "Your interests": "Vos intérêts",
    "Your name": "Votre nom",
    "Your next chapter starts here": "Votre prochain chapitre commence ici",
    "Your next opportunity is waiting.":
        "Votre prochaine possibilité vous attend.",
    "Your story stays editable. Use your own voice.":
        "Votre récit reste modifiable. Gardez votre voix.",
    "Your toolkit": "Votre boîte à outils",
    "YOUR NEXT CHAPTER": "VOTRE PROCHAIN CHAPITRE",
    "YOUR NEXT BEST STEP": "VOTRE PROCHAINE ÉTAPE",
    "A profile that grows with you.": "Un profil qui évolue avec vous.",
    "A profile that fits.": "Un profil qui vous ressemble.",
    "Update your details whenever life changes.":
        "Actualisez vos renseignements au fil de votre parcours.",
    "Discard this import?": "Abandonner cette importation?",
    "Applied fields stay saved. Unapplied suggestions and pasted text will be discarded.":
        "Les champs appliqués restent enregistrés. Les suggestions non appliquées et le texte collé seront supprimés.",
    "Could not load your profile. Please try again.":
        "Impossible de charger votre profil. Veuillez réessayer.",
    "You’ve already done a lot.": "Vous avez déjà fait beaucoup.",
    "Upload a résumé": "Téléverser un CV",
    "Choose a document from your device.":
        "Choisissez un document sur votre appareil.",
    "Paste LinkedIn details": "Coller des renseignements LinkedIn",
    "Use text from your profile or export.":
        "Utilisez le texte de votre profil ou de son exportation.",
    "Imported details are suggestions. Confirm each field before updating your profile.":
        "Les renseignements importés sont des suggestions. Confirmez chaque champ avant de modifier votre profil.",
    "Enter details myself": "Saisir mes renseignements",
    "Your space. Your rules.": "Votre espace. Vos choix.",
    "Account, preferences, and support.": "Compte, préférences et assistance.",
    "Profile & education": "Profil et études",
    "Keep your details up to date.": "Gardez vos renseignements à jour.",
    "French": "Français",
    "View your plan and remaining allowance.":
        "Consultez votre forfait et votre quota restant.",
    "Find an answer or get in touch.": "Trouvez une réponse ou contactez-nous.",
    "Matches, deadlines, and community":
        "Recommandations, échéances et communauté",
    "GPA calculator": "Calcul de moyenne",
    "GPA converter": "Conversion de moyenne",
    "Explore what your next grade changes.":
        "Découvrez l’effet de votre prochaine note.",
    "Understand a different grading scale.":
        "Comprenez une autre échelle de notation.",
    "Your semester, clearly.": "Votre semestre, en clair.",
    "All terms": "Tous les semestres",
    "Courses": "Cours",
    "Term GPA": "Moyenne du semestre",
    "Default 4.0 scale": "Échelle de 4,0 par défaut",
    "My courses": "Mes cours",
    "Course grades": "Notes des cours",
    "Build a picture of your semester.":
        "Dressez le portrait de votre semestre.",
    "Save course": "Enregistrer le cours",
    "Small steps. Real growth.": "De petits pas. De vrais progrès.",
    "Choose a direction. Build your momentum.":
        "Choisissez une direction. Prenez votre élan.",
    "Make your next step a meaningful one.":
        "Donnez du sens à votre prochaine étape.",
    "Save goal": "Enregistrer l’objectif",
    "Goals in this stage will appear here.":
        "Les objectifs à cette étape apparaîtront ici.",
    "Give your week a plan.": "Planifiez votre semaine.",
    "Your saved deadlines and degree plan.":
        "Vos échéances et votre parcours d’études enregistrés.",
    "Next 7 days": "Les 7 prochains jours",
    "Upcoming deadlines": "Échéances à venir",
    "Password updated.": "Mot de passe mis à jour.",
    "This reset link is unavailable.":
        "Ce lien de réinitialisation est indisponible.",
    "A fresh start.": "Un nouveau départ.",
    "Your new password is ready": "Votre nouveau mot de passe est prêt",
    "Your password was updated. Use your new password the next time you sign in.":
        "Votre mot de passe a été mis à jour. Utilisez-le lors de votre prochaine connexion.",
    "Request a new reset link": "Demander un nouveau lien de réinitialisation",
    "This link is missing, invalid or expired. Request a new link using the email linked to your account.":
        "Ce lien est absent, invalide ou expiré. Demandez un nouveau lien avec l’adresse courriel associée à votre compte.",
    "Choose a new password with at least 8 characters. Your current app session will not change automatically.":
        "Choisissez un nouveau mot de passe d’au moins 8 caractères. Votre session actuelle ne changera pas automatiquement.",
    "New password": "Nouveau mot de passe",
    "Confirm password": "Confirmer le mot de passe",
    "Password must be at least 8 characters.":
        "Le mot de passe doit contenir au moins 8 caractères.",
    "Passwords do not match.": "Les mots de passe ne correspondent pas.",
    "Update password": "Mettre à jour le mot de passe",
    "Updating password": "Mise à jour du mot de passe",
    "Your new password has not been saved.":
        "Votre nouveau mot de passe n’a pas été enregistré.",
    "Could not update your password. Please try again.":
        "Impossible de mettre à jour votre mot de passe. Veuillez réessayer.",
    "The server did not confirm the password update. Please try again.":
        "Le serveur n’a pas confirmé la mise à jour du mot de passe. Veuillez réessayer.",
    "Reset link is invalid or has expired.":
        "Le lien de réinitialisation est invalide ou expiré.",
    "Another reset link is ready. Finish or close this screen to open it.":
        "Un autre lien de réinitialisation est prêt. Terminez ou fermez cet écran pour l’ouvrir.",
    "Return to the app": "Revenir à l’application",
    "Already have a reset link?":
        "Vous avez déjà un lien de réinitialisation ?",
    "Paste reset link": "Coller le lien de réinitialisation",
    "Open reset link": "Ouvrir le lien de réinitialisation",
    "Paste the complete reset link from your MyOccasio email.":
        "Collez le lien de réinitialisation complet reçu dans votre courriel MyOccasio.",
    "Recorded grade": "Note enregistrée",
    "Edit course to update your recorded grade.":
        "Modifiez le cours pour actualiser votre note enregistrée.",
    "This draft has not been saved.": "Ce brouillon n’a pas été enregistré.",
    "Start with your story.": "Commencez par votre récit.",
    "A first draft, shaped by your experience.":
        "Un premier brouillon inspiré de votre expérience.",
    "Drafting support can help you begin. Review every detail and make it yours.":
        "L’aide à la rédaction peut vous aider à commencer. Relisez chaque détail et adaptez le texte à votre voix.",
    "What are you writing?": "Que rédigez-vous?",
    "Scholarship personal statement": "Lettre de motivation pour une bourse",
    "What should it highlight?": "Que faut-il mettre en valeur?",
    "Leadership & community impact": "Leadership et engagement communautaire",
    "Use from my story": "Utiliser les éléments de mon récit",
    "Add notes to My story before creating a draft.":
        "Ajoutez des notes à Mon récit avant de créer un brouillon.",
    "Financial context stays private":
        "Votre situation financière reste privée",
    "Allow the selected notes to be sent to the AI service for this draft.":
        "Autoriser l’envoi des notes choisies au service d’IA pour ce brouillon.",
    "Uses AI allowance · Review before sharing":
        "Utilise votre quota d’IA · Relisez avant de partager",
    "Create a starting draft": "Créer un premier brouillon",
    "Writing": "Rédaction",
    "Highlight": "À mettre en valeur",
    "Saved to your profile": "Enregistré dans votre profil",
    "Your story starts here.": "Votre récit commence ici.",
    "Add a few notes about your background, interests and experiences.":
        "Ajoutez quelques notes sur votre parcours, vos intérêts et vos expériences.",
    "Edit saved statement": "Modifier la lettre enregistrée",
    "Enter your statement.": "Saisissez votre lettre.",
    "Good things happen here.": "De belles choses se passent ici.",
    "Celebrate a step, big or small.":
        "Célébrez chaque étape, petite ou grande.",
    "Meet students with a shared direction.":
        "Rencontrez des étudiants qui partagent vos objectifs.",
    "You don’t have to figure it out alone.": "Vous pouvez avancer ensemble.",
    "Start a conversation.": "Lancez une conversation.",
    "Your post is visible to the community. Leave out personal contact details.":
        "Votre publication est visible par la communauté. N’y incluez pas vos coordonnées personnelles.",
    "Publish post": "Publier",
    "A moment worth sharing": "Un moment à partager",
    "A little shared wisdom.": "Un peu de sagesse partagée.",
    "Reply": "Répondre",
    "Replies": "Réponses",
    "Add a thoughtful reply…": "Ajoutez une réponse réfléchie…",
    "Posting comment": "Publication du commentaire",
    "Your comment has not been posted.":
        "Votre commentaire n’a pas été publié.",
    "Could not post your comment. Your draft is still here.":
        "Impossible de publier votre commentaire. Votre brouillon est conservé.",
    "View event": "Voir l’événement",
    "Registered": "Inscrit",
    "Make room for your next step.":
        "Faites une place à votre prochaine étape.",
    "Event registration confirmed.": "Inscription à l’événement confirmée.",
    "Event registration cancelled.": "Inscription à l’événement annulée.",
    "Personalization": "Personnalisation",
    "Your question has not been sent.": "Votre question n’a pas été envoyée.",
    "Upcoming": "À venir",
    "Supporting documents": "Pièces justificatives",
    "Submitted documents": "Documents soumis",
    "Manage supporting documents": "Gérer les pièces justificatives",
    "View submitted documents": "Voir les documents soumis",
    "No supporting documents": "Aucune pièce justificative",
    "No supporting documents will be sent.":
        "Aucune pièce justificative ne sera envoyée.",
    "I reviewed the documents that will be shared.":
        "J’ai vérifié les documents qui seront transmis.",
    "Files stay private until you review and submit. External provider applications are completed on the provider’s website.":
        "Les fichiers restent privés jusqu’à votre vérification et soumission. Les candidatures externes sont remplies sur le site de l’organisme.",
    "Refresh the workspace before reviewing documents again.":
        "Actualisez cet espace avant de vérifier à nouveau les documents.",
    "The copies you shared.": "Les copies que vous avez transmises.",
    "A little evidence goes a long way.": "Des preuves qui font la différence.",
    "Submitted copies stay unchanged when you edit or remove your private documents.":
        "Les copies soumises restent inchangées lorsque vous modifiez ou supprimez vos documents privés.",
    "Up to 3 PDF or DOCX files, 4 MB each. Uploading keeps them private until you review and submit.":
        "Jusqu’à 3 fichiers PDF ou DOCX de 4 Mo chacun. Les fichiers téléversés restent privés jusqu’à votre vérification et soumission.",
    "Only files you add and review will be included when you submit.":
        "Seuls les fichiers que vous ajoutez et vérifiez seront inclus dans votre soumission.",
    "Choose document": "Choisir un document",
    "Use saved résumé": "Utiliser le CV enregistré",
    "Attach saved résumé?": "Joindre le CV enregistré?",
    "Add a private copy of your current profile résumé to this application. It will be shared only after you review and submit.":
        "Ajoutez une copie privée du CV de votre profil à cette candidature. Elle sera transmise seulement après votre vérification et soumission.",
    "Attach résumé": "Joindre le CV",
    "Review selected file": "Vérifier le fichier choisi",
    "Upload privately": "Téléverser en privé",
    "This file has not been added to your application.":
        "Ce fichier n’a pas été ajouté à votre candidature.",
    "You have reached the 3-document limit. Remove a file before adding another.":
        "Vous avez atteint la limite de 3 documents. Supprimez un fichier avant d’en ajouter un autre.",
    "Check the provider’s requirements. Attaching a file does not submit an application.":
        "Vérifiez les exigences de l’organisme. Joindre un fichier ne soumet pas une candidature.",
    "Supporting document saved privately.":
        "Pièce justificative enregistrée en privé.",
    "Remove supporting document?": "Supprimer cette pièce justificative?",
    "This removes the private file from this application. Previously submitted copies stay unchanged.":
        "Le fichier privé sera supprimé de cette candidature. Les copies déjà soumises restent inchangées.",
    "Remove document": "Supprimer le document",
    "Supporting document removed.": "Pièce justificative supprimée.",
    "Choose a PDF or DOCX document.": "Choisissez un document PDF ou DOCX.",
    "Could not read the supporting document details. Please refresh.":
        "Impossible de lire les renseignements du document. Veuillez actualiser.",
    "Supporting documents are unavailable on this server.":
        "Les pièces justificatives ne sont pas disponibles sur ce serveur.",
    "The supporting document could not be downloaded safely. Please refresh.":
        "Impossible de télécharger ce document de manière sécurisée. Veuillez actualiser.",
    "Review your supporting documents before submitting.":
        "Vérifiez vos pièces justificatives avant de soumettre.",
    "Could not update the supporting documents. Please try again.":
        "Impossible de modifier les pièces justificatives. Veuillez réessayer.",
    "The supporting documents changed. Review them again before submitting.":
        "Les pièces justificatives ont changé. Vérifiez-les à nouveau avant de soumettre.",
    "Help": "Aide",
    "Follow device": "Selon l’appareil",
    "Only the right nudges.": "Les bons rappels, au bon moment.",
    "Choose what you’d like to hear about.":
        "Choisissez les nouvelles que vous souhaitez recevoir.",
    "Opportunities that fit your profile":
        "Des possibilités adaptées à votre profil",
    "A heads-up before saved items close":
        "Un rappel avant la clôture des possibilités enregistrées",
    "Progress and next-step reminders":
        "Des nouvelles de votre progression et des rappels utiles",
    "Replies and coffee chat requests":
        "Des réponses et des demandes de rencontre",
    "A little inspiration, once a week":
        "Un peu d’inspiration, une fois par semaine",
    "A little heads-up.": "Un petit rappel.",
    "Recent activity from your MyOccasio account.":
        "L’activité récente de votre compte MyOccasio.",
    "Manage notification preferences": "Gérer les préférences de notification",
    "Privacy & account": "Confidentialité et compte",
    "Your data, privacy, and account controls.":
        "Vos données, votre confidentialité et les paramètres de votre compte.",
    "Your information. Your say.": "Vos renseignements. Vos choix.",
    "Keep control of your MyOccasio account.":
        "Gardez le contrôle de votre compte MyOccasio.",
    "Understand how your data is used.":
        "Comprenez comment vos données sont utilisées.",
    "Read the terms for using MyOccasio.":
        "Consultez les conditions d’utilisation de MyOccasio.",
    "Account actions": "Actions du compte",
    "Deletion requires a separate confirmation.":
        "La suppression exige une confirmation distincte.",
    "Assessment estimate": "Estimation selon les évaluations",
    "Scored course weight": "Pondération déjà notée",
    "Check assessment weights and scores before using an estimate.":
        "Vérifiez la pondération et les notes des évaluations avant d’utiliser une estimation.",
    "Add assessment scores to see an estimate.":
        "Ajoutez des notes d’évaluation pour voir une estimation.",
    "Weighted average of scored assessments. Pending work is excluded. This does not change your recorded grade.":
        "Moyenne pondérée des évaluations notées. Les travaux en attente sont exclus. Cela ne modifie pas votre note enregistrée.",
    "Pending": "En attente",
    "Target": "Cible",
    "Target date not set": "Date cible non définie",
    "complete": "terminé",
    "Create a goal": "Créer un objectif",
    "Progress not set": "Progression non définie",
    "Let’s work it out.": "Trouvons une solution.",
    "Answers and a little human help.":
        "Des réponses et un peu d’aide humaine.",
    "Search help": "Rechercher dans l’aide",
    "Common questions": "Questions fréquentes",
    "How are matches chosen?":
        "Comment les recommandations sont-elles choisies?",
    "Matches use the details saved in your profile. Keep your education, interests and preferences up to date, and check each provider’s requirements before applying.":
        "Les recommandations utilisent les renseignements de votre profil. Gardez vos études, vos intérêts et vos préférences à jour, et vérifiez les exigences de chaque organisme avant de postuler.",
    "Where do I submit an application?": "Où soumettre ma candidature?",
    "Open the application workspace. MyOccasio submits directly only when the provider supports it and you confirm. Otherwise, use the official provider website. Saving or tracking an opportunity does not submit an application.":
        "Ouvrez l’espace de candidature. MyOccasio soumet directement seulement si l’organisme le permet et après votre confirmation. Sinon, utilisez le site officiel de l’organisme. Enregistrer ou suivre une possibilité ne soumet pas une candidature.",
    "How does AI allowance work?": "Comment fonctionne le quota d’IA?",
    "Your plan and remaining allowance appear in Plan & AI allowance. Drafting and coaching requests may use that allowance. Review generated text before saving or sharing it.":
        "Votre forfait et votre quota restant figurent dans Forfait et quota d’IA. Les demandes de rédaction et d’accompagnement peuvent utiliser ce quota. Relisez les textes générés avant de les enregistrer ou de les partager.",
    "No matching answers": "Aucune réponse correspondante",
    "Try another search or contact support below.":
        "Essayez une autre recherche ou contactez l’assistance ci-dessous.",
    "Weekly study plan": "Plan d’étude hebdomadaire",
    "Week of": "Semaine du",
    "Availability and time estimates stay on this device. Plans use your current saved deadlines.":
        "Vos disponibilités et vos estimations restent sur cet appareil. Les plans utilisent vos échéances actuellement enregistrées.",
    "THIS WEEK": "CETTE SEMAINE",
    "hours": "heures",
    "thoughtfully planned.": "planifiées avec soin.",
    "Could not load your study plan":
        "Impossible de charger votre plan d’étude",
    "Could not load your deadlines or saved study preferences. Try again.":
        "Impossible de charger vos échéances ou vos préférences d’étude. Veuillez réessayer.",
    "Your study preferences have not been saved on this device.":
        "Vos préférences d’étude ne sont pas enregistrées sur cet appareil.",
    "Reloading will replace your unsaved study preferences.":
        "L’actualisation remplacera vos préférences d’étude non enregistrées.",
    "Add study availability before building your plan.":
        "Ajoutez vos disponibilités avant de créer votre plan.",
    "Study preferences saved on this device.":
        "Préférences d’étude enregistrées sur cet appareil.",
    "Could not save your study preferences. Please try again.":
        "Impossible d’enregistrer vos préférences d’étude. Veuillez réessayer.",
    "Study plan exported.": "Plan d’étude exporté.",
    "Could not export your study plan. Please try again.":
        "Impossible d’exporter votre plan d’étude. Veuillez réessayer.",
    "No upcoming deadlines to plan": "Aucune échéance à venir à planifier",
    "Save an upcoming deadline in Study plan & deadlines, then return here. Completed and past-due deadlines are excluded.":
        "Enregistrez une échéance à venir dans Plan d’étude et échéances, puis revenez ici. Les échéances terminées ou dépassées sont exclues.",
    "Choose your available time, review each estimate, then build your plan.":
        "Choisissez vos disponibilités, vérifiez chaque estimation, puis créez votre plan.",
    "Previous week": "Semaine précédente",
    "Next week": "Semaine suivante",
    "Week": "Semaine",
    "No sessions fit this week. Review availability, estimates or the next week.":
        "Aucune séance ne peut être planifiée cette semaine. Vérifiez vos disponibilités, vos estimations ou la semaine suivante.",
    "Some work does not fit before its deadline.":
        "Certains travaux ne peuvent pas être planifiés avant leur échéance.",
    "Increase availability or review your time estimates. Unscheduled work is not marked complete.":
        "Augmentez vos disponibilités ou révisez vos estimations. Les travaux non planifiés ne sont pas marqués comme terminés.",
    "unscheduled": "non planifiées",
    "Edit availability": "Modifier mes disponibilités",
    "Time estimates": "Estimations de temps",
    "Save & build plan": "Enregistrer et créer le plan",
    "Export plan": "Exporter le plan",
    "Daily sessions are estimates, not timed appointments. Check the actual deadline time before you study. Plans cover up to 24 weeks.":
        "Les séances quotidiennes sont des estimations sans horaire fixe. Vérifiez l’heure exacte de l’échéance avant d’étudier. Les plans couvrent au plus 24 semaines.",
    "Choose up to 8 hours per day and 40 hours per week. Earlier days in the current week are not scheduled.":
        "Choisissez au plus 8 heures par jour et 40 heures par semaine. Les jours déjà passés de la semaine ne sont pas planifiés.",
    "Monday": "Lundi",
    "Tuesday": "Mardi",
    "Wednesday": "Mercredi",
    "Thursday": "Jeudi",
    "Friday": "Vendredi",
    "Saturday": "Samedi",
    "Sunday": "Dimanche",
    "Unavailable": "Indisponible",
    "Choose at most 40 study hours per week.":
        "Choisissez au plus 40 heures d’étude par semaine.",
    "New tasks start with a 1-hour estimate. Review the total work needed for each deadline in half-hour steps.":
        "Les nouveaux travaux ont une estimation initiale de 1 heure. Vérifiez le temps total nécessaire pour chaque échéance, par demi-heures.",
    "Estimated hours": "Heures estimées",
    "Use 0.5 to 200 hours in half-hour steps.":
        "Utilisez entre 0,5 et 200 heures, par demi-heures.",
    "All courses": "Tous les cours",
    "Course": "Cours",
    "Week start": "Début de la semaine",
    "Day": "Jour",
    "Task": "Travail",
    "Due date": "Échéance",
    "Hours": "Heures",
    "Unscheduled": "Non planifié",
    "Refresh": "Actualiser",
    "Edit my interests": "Modifier mes intérêts",
    "hour": "heure",
    "Keep your place.": "Gardez votre élan.",
    "Saved opportunities are still here.":
        "Vos possibilités enregistrées sont toujours ici.",
    "Connection unavailable. Showing a read-only saved copy.":
        "Connexion indisponible. Affichage d’une copie enregistrée en lecture seule.",
    "Last checked": "Dernière vérification",
    "Only part of this account’s list is available offline.":
        "Seule une partie de la liste de ce compte est disponible hors ligne.",
    "Try connecting again": "Réessayer la connexion",
    "No saved opportunities in this copy":
        "Aucune possibilité enregistrée dans cette copie",
    "Reconnect to load your current saved list.":
        "Reconnectez-vous pour charger votre liste actuelle.",
    "Current deadlines and availability may have changed. Reconnect before continuing.":
        "Les échéances et la disponibilité peuvent avoir changé. Reconnectez-vous avant de continuer.",
    "Saved offline": "Enregistré hors ligne",
    "Your session changed. Please sign in again.":
        "Votre session a changé. Veuillez vous reconnecter.",
    "PLANNED WEEK": "SEMAINE PLANIFIÉE",
    "Clear search": "Effacer la recherche",
    "Reconnect to update your saved list.":
        "Reconnectez-vous pour actualiser votre liste enregistrée.",
    "A helpful heads-up.": "Un petit rappel utile.",
    "Remind me": "Me le rappeler",
    "1 day before": "1 jour avant",
    "3 days before": "3 jours avant",
    "1 week before": "1 semaine avant",
    "Reminder time": "Heure du rappel",
    "Save reminder": "Enregistrer le rappel",
    "Reminder saved on this device.": "Rappel enregistré sur cet appareil.",
    "Reminders stay on this device and are cleared when you sign out. For dates without a time, we use 9 AM on this device. Delivery may be delayed by your phone.":
        "Les rappels restent sur cet appareil et sont effacés à la déconnexion. Pour les dates sans heure, nous utilisons 9 h sur cet appareil. Votre téléphone peut retarder leur réception.",
    "No reminder time is available before this deadline.":
        "Aucun horaire de rappel n’est disponible avant cette échéance.",
    "Could not save your reminder. Please try again.":
        "Impossible d’enregistrer votre rappel. Veuillez réessayer.",
    "Choose a reminder time that is still in the future.":
        "Choisissez un horaire de rappel à venir.",
    "Allow notifications in device settings to save a reminder.":
        "Autorisez les notifications dans les réglages de l’appareil pour enregistrer un rappel.",
    "Could not load your device reminders. Please try again.":
        "Impossible de charger vos rappels sur cet appareil. Veuillez réessayer.",
    "This device has reached its reminder limit. Remove a reminder first.":
        "Cet appareil a atteint la limite de rappels. Supprimez d’abord un rappel.",
    "Device reminders": "Rappels sur cet appareil",
    "Your deadline reminders on this phone.":
        "Vos rappels d’échéances sur ce téléphone.",
    "Device reminders unavailable": "Rappels de l’appareil indisponibles",
    "A little nudge, on your terms.": "Un petit coup de pouce, à votre rythme.",
    "These reminders are saved on this device. Website email preferences are separate.":
        "Ces rappels sont enregistrés sur cet appareil. Les préférences de courriel du site Web sont distinctes.",
    "Notifications allowed on this device":
        "Notifications autorisées sur cet appareil",
    "Notifications are off on this device":
        "Les notifications sont désactivées sur cet appareil",
    "Allow notifications in device settings to receive your reminders.":
        "Autorisez les notifications dans les réglages de l’appareil pour recevoir vos rappels.",
    "Open device settings": "Ouvrir les réglages de l’appareil",
    "Could not open device settings. Please try again.":
        "Impossible d’ouvrir les réglages de l’appareil. Veuillez réessayer.",
    "No device reminders yet": "Aucun rappel sur cet appareil",
    "Open an opportunity and choose Remind me to set a reminder for its real deadline.":
        "Ouvrez une possibilité et choisissez Me le rappeler pour programmer un rappel avant son échéance réelle.",
    "Change reminder": "Modifier le rappel",
    "Remove reminder": "Supprimer le rappel",
    "Remove reminder?": "Supprimer le rappel ?",
    "This only removes the reminder on this device.":
        "Cette action supprime uniquement le rappel sur cet appareil.",
    "Reminders are cleared when you sign out. Check the provider’s current deadline before applying.":
        "Les rappels sont effacés à la déconnexion. Vérifiez l’échéance actuelle du fournisseur avant de postuler.",
    "Sign in with Google": "Se connecter avec Google",
    "Sign up with Google": "S’inscrire avec Google",
    "Checking Google availability…":
        "Vérification de la disponibilité de Google…",
    "Google is not available right now. Continue with email or try again.":
        "Google est indisponible pour le moment. Continuez avec votre courriel ou réessayez.",
    "Check Google availability again":
        "Vérifier à nouveau la disponibilité de Google",
    "Continue with Google": "Continuer avec Google",
    "Continue with Apple": "Continuer avec Apple",
    "Your next chapter is waiting.": "Votre prochain chapitre vous attend.",
    "Create your free MyOccasio account.":
        "Créez votre compte MyOccasio gratuit.",
    "Full name": "Nom complet",
    "Create a strong password": "Créez un mot de passe robuste",
    "By continuing, you agree to our Terms of service and Privacy policy.":
        "En continuant, vous acceptez nos conditions d’utilisation et notre politique de confidentialité.",
    "Terms and privacy": "Conditions et confidentialité",
    "Done": "Terminé",
    "View Terms of service and Privacy policy":
        "Consulter les conditions d’utilisation et la politique de confidentialité",
    "Apple sign-in unavailable": "Connexion Apple indisponible",
    "Google sign-in unavailable": "Connexion Google indisponible",
    "Apple sign-in is not available yet. Please use your email and password.":
        "La connexion Apple n’est pas encore disponible. Utilisez votre courriel et votre mot de passe.",
    "Use email": "Utiliser le courriel",
    "or with email": "ou avec un courriel",
    "Forgot password?": "Mot de passe oublié?",
    "Waiting for Google sign-in…": "En attente de la connexion Google…",
    "Finish signing in in your system browser, then return here.":
        "Terminez la connexion dans le navigateur système, puis revenez ici.",
    "Cancel sign-in": "Annuler la connexion",
    "Cancelling…": "Annulation…",
    "Could not cancel sign-in. Please try again.":
        "Impossible d’annuler la connexion. Veuillez réessayer.",
    "Google sign-in is unavailable. Use your email and password.":
        "La connexion Google est indisponible. Utilisez votre courriel et votre mot de passe.",
    "The sign-in service returned an invalid response.":
        "Le service de connexion a renvoyé une réponse non valide.",
    "The sign-in callback could not be verified. Please try again.":
        "Le retour de connexion n’a pas pu être vérifié. Veuillez réessayer.",
    "Google sign-in did not finish. Please try again.":
        "La connexion Google n’a pas abouti. Veuillez réessayer.",
    "Sign-in expired. Please try again.":
        "La connexion a expiré. Veuillez réessayer.",
  };
  static final _lowerFrench = {
    for (final entry in french.entries) entry.key.toLowerCase(): entry.value,
  };
}

class _StringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _StringsDelegate();
  @override
  bool isSupported(Locale locale) =>
      const {'en', 'fr'}.contains(locale.languageCode);
  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture(AppStrings(locale.languageCode));
  @override
  bool shouldReload(_StringsDelegate old) => false;
}
