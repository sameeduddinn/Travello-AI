import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flight_app/ui/themes/theme_system.dart';

class Blog extends StatelessWidget {
  const Blog({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        title: const Text('Blog', style: TravelloTheme.subtitle),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Travel Insights & Tips',
              style: TravelloTheme.title.copyWith(
                color: TravelloTheme.primaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stay updated with latest travel trends, destinations, and tips',
              style: TravelloTheme.paragraph.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _buildBlogCard(
              'Top 10 Tourist Destinations in Pakistan 2026',
              'Discover the most beautiful and must-visit places in Pakistan, from mountain peaks to historical sites.',
              'Travel Guide',
              'March 10, 2026',
              '5 min read',
              Icons.landscape,
            ),
            _buildBlogCard(
              'How to Find Cheap Flights: Expert Tips',
              'Learn insider tricks to save money on flight bookings and find the best deals.',
              'Travel Tips',
              'March 8, 2026',
              '7 min read',
              Icons.flight_takeoff,
            ),
            _buildBlogCard(
              'Pakistan Railways: A Complete Travel Guide',
              'Everything you need to know about train travel in Pakistan - routes, classes, and booking tips.',
              'Railway Guide',
              'March 5, 2026',
              '10 min read',
              Icons.train,
            ),
            _buildBlogCard(
              'AI in Travel: How Technology is Transforming Tourism',
              'Explore how AI and machine learning are revolutionizing the travel industry.',
              'Technology',
              'March 3, 2026',
              '6 min read',
              Icons.psychology,
            ),
            _buildBlogCard(
              'Best Hotels in Karachi: 2026 Edition',
              'A curated list of top-rated hotels in Karachi for every budget.',
              'Accommodation',
              'March 1, 2026',
              '8 min read',
              Icons.hotel,
            ),
            _buildBlogCard(
              'Travel Safety Tips for Solo Travelers',
              'Essential safety guidelines and precautions for traveling alone in Pakistan.',
              'Safety',
              'Feb 28, 2026',
              '5 min read',
              Icons.security,
            ),
            _buildBlogCard(
              'Packing Checklist: Never Forget Essentials Again',
              'The ultimate packing guide for domestic and international trips.',
              'Travel Tips',
              'Feb 25, 2026',
              '4 min read',
              Icons.luggage,
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'More articles coming soon...',
                style: TravelloTheme.caption.copyWith(
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBlogCard(
    String title,
    String description,
    String category,
    String date,
    String readTime,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TravelloTheme.primaryLight.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: TravelloTheme.primaryMain.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: TravelloTheme.primaryMain, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: TravelloTheme.caption.copyWith(
                          color: TravelloTheme.primaryMain,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$date • $readTime',
                        style: TravelloTheme.caption.copyWith(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TravelloTheme.subtitle2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: TravelloTheme.primaryDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TravelloTheme.paragraph.copyWith(
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Read More',
                      style: TravelloTheme.paragraph.copyWith(
                        color: TravelloTheme.primaryMain,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: TravelloTheme.primaryMain,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
