# SAE_Radio_Campus_Orl-ans
onjour à vous,



Merci pour les captures d’écran, c’est déjà pas mal chouette. M. Arsouze m’a transmis l’idée d’une présentation en capture vidéo qui pourrait être complémentaire à ces captures. Si vous pouvez me faire une visite vidéo ce serait chouette.



Pour le coup je n’ai que des appareils Apple, est-ce que vous avez moyen de me la faire tester sur iphone directement ?



Pour les fichiers graphiques que je vous aie envoyés, je vous propose qu’on les désigne comme « icons » qui seront utilisés sur les petits formats et icon d’application. Ce sera une première variable. Il viendront en complément du « logo » que vous récupérerez depuis l’API. Aussi, à terme je souhaite faire développer directement dans l’API du site de radiocampus.fr une variable pour les icons. Donc à terme ils seront récupérables de cette manière. Prévoyez donc cette portabilité future.



De manière générale, préparez une documentation texte et ajoutez-y les variables customs que vous avez créées afin que je puisse le transmettre afin de l’intégrer au back de radiocampus.fr. Histoire que votre appli, à terme, ne stock pas d’éléments en plus de ce qui sera dispo sur l’api radiocampus.fr. Ça fait sens ?



Quelques précisions afin que vous puissiez continuer à développer en autonomie jusqu’à que nous nous voyions.



Pour la page d’accueil, plutôt qu’une mosaïque des radios avec la possibilité de les écouter (on peut réserver cette page pour ailleurs, comme rubrique d’un onglet « explorer l’Univers Radio·s Campus » par exemple », je vous propose une page avec un sélecteur de ville qui demande à l’utilisateur de choisir sa ville manuellement ou via sa géo-localisation. On pourrait même imaginer une carte interactive ? L’idée est de guider l’utilisateur sur ses premiers pas dans l’appli en lui demandant de facto de choisir sa ville (c’est un choix éditorial qui répond à une demande de la part des radios).



Pour la page radio sans site internet :

	Je vous propose de créer des modules que la radio pourra décider de changer l’ordre d’affichage au défilement.

> Un module à la Une qui met en valeur au choix une émission, un épisode, un article ou un événement

> Un module avec les dernières actualités de la radio

> Un module avec les événements à venir

> Un module avec les derniers replay de toutes les émissions confondues ou une sélection d’émission, soit custom, soit selon des tags à définir.

> Un module avec une sélection d’articles en fonction du ou des tags sélectionnés.

> Un module qui met en avant une émission et ses derniers épisodes en date.

> Un module Avec son Top Campus du mois.

> Un module avec les flux direct + métadonnée du titre en cours/émission en cours (parfois certaines radios ont plusieurs flux radios en direct (le principal et des webradios musicales)).

> Un module avec une sélection de vidéos verticales (récupérer les reels insta/tiktok via API ? Ou via flux youtube ou peertube).

> Un module grille d’antenne de la journée



Le site radiocampus.fr propose déjà un module qui présente une sélection d’articles, programmes et épisodes par flux thématique. 



Parfois certaines radios auront peut-être leur propre API depuis leur site web avec des infos complémentaires. Peut-être créer un champs pour ajouter du contenu custom à partir de leur propre API ? Comment on peut créer des modules qui permettent facilement de mettre en forme du contenu ainsi récupéré ?

Peut-être aussi via des fluxs RSS ou iFrame ?



>>>> De manière globale, imaginez combien de déclinaisons et présentations différentes on peut donner à une même information. <<<<<< 



(Pour anecdote en Arts appliqués c’est un exercice de base qu’on donne aux étudiants. Ils doivent dessiner une même éponge ou un même panier ou autre objets simple de 100 manières différentes. Forçant ainsi à se plier le cerveau en quatre pour trouver de nouvelles manières de présenter l’objet sous un nouveau jour, un nouvel aspect. Comprenez ça et soyez capable de le mettre en oeuvre dans vos projets, vous aurez une sacré longueur d’avance dans ce secteurs comparé à d’autres juniors ).



Si vous souhaitez avoir des idées, analyser, comprendre parfaire votre oeil et fournir vos références : 

https://www.radiofrance.fr/
https://lesonunique.com/mysun 
https://radio-boa.bzh/fr (celui là à une particularité, je vous laisse le comprendre. Indice, on retrouve cette nomenclature  de site web ailleurs. Pourquoi ?).
https://murmures.org/ (un projet de Radio Campus Angers qui mérite vraiment le détour)
https://www.nova.fr/ 


Méthodologie :

Analyser un projet, comprenez les choix éditoriaux, artistiques, les partis prix de présenter l’info de cette manière et pas d’une autre. Imaginez dans votre esprit 3 autres manières que l’éditeur aurait pu choisir pour présenter la même info avec 3 angles complètement différent. Briser les limites de votre imagination.



—— 



Côté expérience utilisateur, c’est déjà pas mal, c’est même propre. J’ai envie de vous emmener encore plus loin si vous le voulez bien.



Déjà pour commencer, avez-vous déjà parcouru le Apple Human Interface Guidelines ?

https://developer.apple.com/design/human-interface-guidelines/



Il y a toute une philosophie axée sur l’expérience utilisateur à explorer et comprendre. Je vous invite à en prendre connaissance. C’est assez puissant comme outil dans la philosophie d’interaction, tellement puissant que les grands principes énoncés sont aussi valables dans d’autres domaines comme l’animation de collectif, d’une équipe, etc.



Une fois que vous aurez compris et mis en relation ces informations avec votre propre expérience personnelle dans le monde numérique, je souhaite vous partager trois applications dont l’interface utilisateur mérite de détour :



https://apps.apple.com/fr/app/not-boring-weather/id1531063436 (et plus largement https://apps.apple.com/fr/app-bundle/not-boring-apps/id1847738447) 
https://apps.apple.com/fr/app/md-vinyle-lecteur-de-musique/id1606306441
https://apps.apple.com/fr/app/clocks-a-fun-standby-mode/id6742508073




Des « not boring apps », qui invite ce qu’on pourrait appeler le « fun » mais lorsqu’on creuse un peu on se rend compte à quel point ces apps répondent à deux dimensions que j’aimerais que vous intégriez dans votre production :

la gamification, qui invite à une expérience ludique et proche des mécaniques de jeu vidéo,
le réel, des objets qui donnent la sensation, dans la gestuelle, dans le retour haptique, dans les micro-mouvements, bref dans toutes ces micro-informations qui donnent le sentiment d’utiliser un objet physique ancré dans le monde réel, si familier et qui a se goût de reviens-y tant il est satisfaisant.  Posez-vous la question « de quels objets physiques dans le studio d’une radio ou à la maison puis-je m’inspirer pour développer une interface satisfaisante ». D’ailleurs pensez à quel point le disque vinyle et les platines sont revenues à la mode après avoir été boudés pendant des années. Qu’est-ce qu’il y a comme d’autres supports qu’on peut faire revivre de cette manière ludique ? 


Maintenant que la mécanique est en bonne voie de rouler, je vous propose d’explorer ce rapport à l’interface que l’utilisateur peut avoir. 



L’idée c’est d’avoir une app qui vous accompagne du matin au petit dej, dans le tram, le vélo ou la voiture jusqu’à la fac ou au boulot, pendant le travail pour se concentrer sur une tâche, le midi avec les collègues, les amis, jusqu’au soir pendant qu’on se fait à manger ou qu’on est sous la douche avant d’aller au lit.



Ainsi, je vous laisserai dans un troisième temps :



réfléchir et itérer sur la déclinaison de l’app sur tous les écrans > du téléphone à la tablette, en passant par l’app desktop, sur la TV connectée et la voiture connectée. Des widget pour écran d’accueil aussi ? Faciliter l’accès à l’app même quand elle est pas ouverte.
explorer comment proposer des intégrations avec, en priorité des logiciels et app open source (c’est notre ADN) qu’on peut utiliser au quotidien pour travailler, étudier, se divertir, etc.




Objectifs qui apparaissent :



Limiter la friction d’utilisation

Augmenter la satisfaction d’utilisation en développant l’interaction avec les 5 sens.

Ouvrir une nouvelle voie en proposer une interface encore vue nulle part ailleurs pour un média ou une radio

Se démarquer avec une application qui ne ressemble pas à ce qu’on a l’habitude de rencontre dans le secteur mais qui sera familière à l’utilisation

Adapter l’application aux différents écrans de la vie quotidienne

Ouvrir l’écosystème avec des intégrations logiciels





Est-ce que ça vous parait clair et cohérent ? Dispo pour en discuter au besoin.



Au plaisir,

