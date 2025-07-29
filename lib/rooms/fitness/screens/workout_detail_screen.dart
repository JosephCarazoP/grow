import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grow/rooms/fitness/screens/workout_session_screen.dart';
import '../models/workout.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final Workout workout;
  final Function() onStart;
  final String roomId;

  const WorkoutDetailScreen({
    Key? key,
    required this.workout,
    required this.onStart,
    required this.roomId,
  }) : super(key: key);

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildHeader(), _buildTabBar(), _buildTabContent()],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: widget.workout.imageUrl,
              fit: BoxFit.cover,
              placeholder:
                  (context, url) => Container(
                    color: Colors.grey.shade900,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              errorWidget:
                  (context, url, error) => Container(
                    color: Colors.grey.shade900,
                    child: const Icon(Icons.error_outline, color: Colors.white),
                  ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
        title: Text(
          widget.workout.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_border, color: Colors.white),
          ),
          onPressed: () {},
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.share_outlined, color: Colors.white),
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.workout.getCategoryColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.workout.category,
                  style: TextStyle(
                    color: widget.workout.getCategoryColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.workout.getLevelColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.workout.levelText,
                  style: TextStyle(
                    color: widget.workout.getLevelColor(),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              if (widget.workout.type == WorkoutType.personalized)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'PERSONALIZADO',
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem(
                icon: Icons.timer_outlined,
                value: '${widget.workout.durationMinutes} min',
                label: 'Duración',
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                icon: Icons.local_fire_department_outlined,
                value: '${widget.workout.estimatedCalories} kcal',
                label: 'Calorías',
              ),
              const SizedBox(width: 24),
              _buildStatItem(
                icon: Icons.calendar_today_outlined,
                value: '${widget.workout.days.length} días',
                label: 'Programa',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 22, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.blue,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.white.withOpacity(0.5),
        tabs: const [Tab(text: 'Información'), Tab(text: 'Programa')],
      ),
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: 600,
      child: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [_buildInfoTab(), _buildProgramTab()],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cliente y Descripción combinados
          _buildDescriptionCard(),

          // 2. Frase motivacional animada mejorada
          const SizedBox(height: 24),
          _buildAnimatedMotivationalQuote(),

          // 3. Consejos en slider mejorado
          const SizedBox(height: 24),
          _buildEnhancedTipsSlider(),

          // 4. Recordatorios diversos
          const SizedBox(height: 24),
          _buildDiverseReminders(),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildAnimatedMotivationalQuote() {
    return _AnimatedMotivationalQuote();
  }

  // 2. Slider de consejos mejorado
  Widget _buildEnhancedTipsSlider() {
    final tips = [
      {
        'icon': Icons.water_drop,
        'title': 'Hidratación',
        'description':
            'Mantente hidratado antes, durante y después del ejercicio',
        'gradient': [Color(0xFF00B4DB), Color(0xFF0083B0)],
      },
      {
        'icon': Icons.restaurant_menu,
        'title': 'Nutrición',
        'description':
            'Alimenta tu cuerpo con proteínas y carbohidratos de calidad',
        'gradient': [Color(0xFF56AB2F), Color(0xFFA8E6CF)],
      },
      {
        'icon': Icons.nightlight_round,
        'title': 'Descanso',
        'description': 'El músculo crece durante el descanso, duerme 7-9 horas',
        'gradient': [Color(0xFF667EEA), Color(0xFF764BA2)],
      },
      {
        'icon': Icons.psychology,
        'title': 'Mentalidad',
        'description': 'Mantén una actitud positiva y enfócate en tu progreso',
        'gradient': [Color(0xFFFF8A80), Color(0xFFFF5722)],
      },
      {
        'icon': Icons.timer,
        'title': 'Consistencia',
        'description': 'La clave del éxito está en la constancia diaria',
        'gradient': [Color(0xFFFF6B6B), Color(0xFFEE5A24)],
      },
      {
        'icon': Icons.self_improvement,
        'title': 'Técnica',
        'description': 'Perfecciona la forma antes de aumentar la intensidad',
        'gradient': [Color(0xFF3742FA), Color(0xFF2F3542)],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 20),
          child: ShaderMask(
            shaderCallback:
                (bounds) => const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ).createShader(bounds),
            child: const Text(
              'Consejos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = MediaQuery.of(context).size.width;
            final availableWidth = constraints.maxWidth;

            // Cálculo responsive del ancho de card
            double cardWidth;
            if (screenWidth <= 400) {
              cardWidth = availableWidth * 0.85;
            } else if (screenWidth <= 600) {
              cardWidth = availableWidth * 0.75;
            } else {
              cardWidth = availableWidth * 0.65;
            }

            cardWidth = cardWidth.clamp(280.0, 340.0);

            return SizedBox(
              height: 160, // Aumentado de 120 a 160
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                itemCount: tips.length,
                itemBuilder: (context, index) {
                  final tip = tips[index];
                  return Container(
                    width: cardWidth,
                    margin: EdgeInsets.only(
                      right: 16,
                      left: index == 0 ? 0 : 0,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {},
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (tip['gradient'] as List<Color>)[0].withOpacity(
                                  0.15,
                                ),
                                (tip['gradient'] as List<Color>)[1].withOpacity(
                                  0.08,
                                ),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: (tip['gradient'] as List<Color>)[0]
                                  .withOpacity(0.4),
                              width: 1.2,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(
                              20,
                            ), // Aumentado de 16 a 20
                            child: Row(
                              children: [
                                // Icono con gradiente
                                Container(
                                  width: 52, // Aumentado ligeramente
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: tip['gradient'] as List<Color>,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (tip['gradient']
                                                as List<Color>)[0]
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    tip['icon'] as IconData,
                                    color: Colors.white,
                                    size: 26, // Aumentado ligeramente
                                  ),
                                ),
                                const SizedBox(width: 18), // Aumentado spacing
                                // Texto flexible
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tip['title'] as String,
                                        style: const TextStyle(
                                          fontSize: 17, // Aumentado ligeramente
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(
                                        height: 8,
                                      ), // Aumentado spacing
                                      Text(
                                        tip['description'] as String,
                                        style: TextStyle(
                                          fontSize: 14, // Aumentado de 13 a 14
                                          color: Colors.white.withOpacity(0.8),
                                          height: 1.3, // Mejor line height
                                        ),
                                        maxLines:
                                            3, // Aumentado de 2 a 3 líneas
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDiverseReminders() {
    final reminders = [
      {
        'icon': Icons.schedule,
        'title': 'Mejor momento',
        'subtitle': 'Entrena cuando tengas más energía',
        'gradient': [Color(0xFFFFC107), Color(0xFFFF9800)],
      },
      {
        'icon': Icons.fitness_center,
        'title': 'Técnica primero',
        'subtitle': 'La forma correcta previene lesiones',
        'gradient': [Color(0xFFF44336), Color(0xFFE91E63)],
      },
      {
        'icon': Icons.trending_up,
        'title': 'Progreso gradual',
        'subtitle': 'Aumenta 5-10% cada semana',
        'gradient': [Color(0xFF4CAF50), Color(0xFF8BC34A)],
      },
      {
        'icon': Icons.spa,
        'title': 'Recuperación',
        'subtitle': 'Tu cuerpo crece en el descanso',
        'gradient': [Color(0xFF9C27B0), Color(0xFF673AB7)],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.blue],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback:
                        (bounds) => const LinearGradient(
                          colors: [Colors.purple, Colors.blue],
                        ).createShader(bounds),
                    child: const Text(
                      'Recordatorios',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'Tips importantes para tu progreso',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        ...reminders.asMap().entries.map((entry) {
          final index = entry.key;
          final reminder = entry.value;

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 150)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(30 * (1 - value), 0),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.grey.shade900, Colors.grey.shade800],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Gradiente decorativo lateral
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: 4,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: reminder['gradient'] as List<Color>,
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          // Contenido
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors:
                                          reminder['gradient'] as List<Color>,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (reminder['gradient']
                                                as List<Color>)[0]
                                            .withOpacity(0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    reminder['icon'] as IconData,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reminder['title'] as String,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        reminder['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.7),
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ],
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.1),
            Colors.purple.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cliente info si es personalizado
          if (widget.workout.type == WorkoutType.personalized &&
              widget.workout.clientName != null) ...[
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purple, Colors.blue],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.workout.clientName![0].toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plan personalizado para',
                        style: TextStyle(
                          color: Colors.purple,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.workout.clientName!,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
          ],

          // Descripción
          Text(
            widget.workout.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),

          // Detalles adicionales si existen
          if (widget.workout.frequency != null ||
              widget.workout.pathology != null) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.workout.frequency != null)
                  Expanded(
                    child: _buildMiniDetail(
                      icon: Icons.repeat,
                      label: 'Frecuencia',
                      value: widget.workout.frequency!,
                    ),
                  ),
                if (widget.workout.frequency != null &&
                    widget.workout.pathology != null)
                  const SizedBox(width: 16),
                if (widget.workout.pathology != null)
                  Expanded(
                    child: _buildMiniDetail(
                      icon: Icons.health_and_safety,
                      label: 'Consideraciones',
                      value: widget.workout.pathology!,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniDetail({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue.withOpacity(0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgramTab() {
    final day = widget.workout.days[_selectedDay];

    return Column(
      children: [
        _buildDaySelector(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            children: [
              if (day.warmup != null)
                _buildSimpleSection(
                  title: 'Calentamiento',
                  content: day.warmup!,
                  icon: Icons.directions_run,
                  color: Colors.orange,
                ),
              const SizedBox(height: 16),
              ...day.exercises.asMap().entries.map(
                (entry) => _buildSimpleExerciseItem(entry.value, entry.key + 1),
              ),
              if (day.finalExercises != null) ...[
                const SizedBox(height: 16),
                _buildSimpleSection(
                  title: 'Enfriamiento',
                  content: day.finalExercises!,
                  icon: Icons.self_improvement,
                  color: Colors.green,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleSection({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleExerciseItem(Exercise exercise, int number) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${exercise.sets} series × ${exercise.reps} • ${exercise.rest} descanso',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (exercise.videoUrl != null)
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.play_circle_filled,
                color: Colors.blue,
                size: 28,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.workout.days.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final day = widget.workout.days[index];
          final isSelected = index == _selectedDay;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDay = index;
              });
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? Colors.blue.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isSelected
                          ? Colors.blue.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Center(
                child: Text(
                  day.dayName,
                  style: TextStyle(
                    color:
                        isSelected
                            ? Colors.blue
                            : Colors.white.withOpacity(0.7),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => WorkoutSessionScreen(
                      workout: widget.workout, roomId: widget.roomId,
                    ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Comenzar entrenamiento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedMotivationalQuote extends StatefulWidget {
  @override
  State<_AnimatedMotivationalQuote> createState() =>
      _AnimatedMotivationalQuoteState();
}

class _AnimatedMotivationalQuoteState extends State<_AnimatedMotivationalQuote>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  int _currentQuoteIndex = 0;

  final List<Map<String, String>> quotes = [
    {
      'quote': 'El dolor de hoy es la fuerza de mañana',
      'author': 'Arnold Schwarzenegger',
    },
    {
      'quote': 'Los campeones siguen jugando hasta que lo hacen bien',
      'author': 'Billie Jean King',
    },
    {
      'quote': 'No cuentes los días, haz que los días cuenten',
      'author': 'Muhammad Ali',
    },
    {
      'quote': 'El único mal entrenamiento es el que no se hace',
      'author': 'Anónimo',
    },
    {
      'quote':
          'Tu cuerpo puede soportarlo. Es tu mente la que necesitas convencer',
      'author': 'Anónimo',
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    Future.delayed(const Duration(seconds: 13), _changeQuote);
  }

  void _changeQuote() {
    if (!mounted) return;

    _controller.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _currentQuoteIndex = (_currentQuoteIndex + 1) % quotes.length;
      });
      _controller.forward();
      Future.delayed(const Duration(seconds: 13), _changeQuote);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentQuote = quotes[_currentQuoteIndex];

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                    spreadRadius: -10,
                  ),
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, -20),
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue, Colors.purple],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    currentQuote['quote']!,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      currentQuote['author']!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
