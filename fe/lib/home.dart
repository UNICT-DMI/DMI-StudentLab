import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  
  final List<FeatureCard> _featureCards = [
    FeatureCard(
      title: 'Quiz Interattivo',
      description: 'Metti alla prova le tue conoscenze '
          'con domande a risposta multipla.',
      icon: Icons.quiz,
      color: const Color(0xFF283593), 
      buttonText: 'Inizia Quiz',
    ),
    FeatureCard(
      title: 'Catalogo',
      description: 'Cosming soon..',
      icon: Icons.menu_book,
      color: const Color(0xFF3949AB), 
    ),
    FeatureCard(
      title: 'Altri studenti',
      description: 'Cosming soon',
      icon: Icons.people,
      color: const Color(0xFF5C6BC0), 
    ),
  ];

  // Gestione menu inferiore
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // APPBAR ELEGANTE
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            
            Text(
              'Hi, matricola',
              style: TextStyle(
                fontWeight: FontWeight.w200,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                separatorBuilder: (context, index) => const SizedBox(width: 20),
                itemCount: _featureCards.length,
                itemBuilder: (context, index) {
                  return _buildElevationCard(_featureCards[index], index);
                },
              ),
            ),
          ),

          // Sezione per aggiornamenti importanti
          /* Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F3A).withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF3949AB).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tips_and_updates_outlined,
                  size: 40,
                  color: Color(0xFF64B5F6),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pro Tip del Giorno',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("lorem ispum",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ), */
        ],
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0A2472).withOpacity(0.9),
        ),
        child: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.science_outlined),
              activeIcon: Icon(Icons.science),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.connect_without_contact_outlined),
              activeIcon: Icon(Icons.connect_without_contact),
              label: '',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outlined),
              activeIcon: Icon(Icons.person),
              label: '',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFFBBDEFB), 
          unselectedItemColor: const Color(0xFF90A4AE),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w100),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w100),
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildElevationCard(FeatureCard card, int index) {
    return Container(
      width: 320, 
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                card.color.withOpacity(0.9),
                card.color.withOpacity(0.7),
                const Color(0xFF263238).withOpacity(0.8), 
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        card.icon,
                        size: 32,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      card.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      card.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.8),
                        height: 1.5,
                        fontWeight: FontWeight.w300,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Azione del bottone (da modificare)
                      print('Card ${index + 1} premuta: ${card.title}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      elevation: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          card.buttonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// modello per le card (da modificare)
class FeatureCard {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String buttonText;

  FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.buttonText = "",
  });
}