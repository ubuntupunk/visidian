#!/usr/bin/env python3
import os
import random
from datetime import datetime, timedelta
import yaml
import re

# Test data
project_tags = ['project', 'deadline', 'milestone', 'client', 'team', 'sprint', 'development']
area_tags = ['health', 'finance', 'career', 'learning', 'family', 'fitness', 'skills']
resource_tags = ['reference', 'article', 'book', 'tutorial', 'guide', 'template', 'research']
archive_tags = ['completed', 'archived', 'old', 'inactive', '2023', 'deprecated', 'historical']
gtd_tags = ['next', 'waiting', 'someday', 'reference', 'done']

# Content templates
content_templates = [
    "# {title}\n\nThis is a note about {topic}.\n\n## Key Points\n- Point 1\n- Point 2\n- Point 3",
    "# {title}\n\n## Overview\nDiscussion about {topic}\n\n## Details\n1. First item\n2. Second item",
    "# {title}\n\n> Important note about {topic}\n\n## Notes\n* Note 1\n* Note 2",
]

topics = [
    "Machine Learning", "Vim Configuration", "Project Management",
    "Personal Development", "Software Architecture", "Team Leadership",
    "System Design", "Code Review", "Technical Writing",
    "Database Design", "API Development", "UI/UX Design"
]

def generate_tags(category):
    """Generate a list of tags based on category and random GTD context"""
    tags = []
    
    # Add category-specific tags
    if category == 'projects':
        tags.extend(random.sample(project_tags, random.randint(1, 3)))
    elif category == 'areas':
        tags.extend(random.sample(area_tags, random.randint(1, 3)))
    elif category == 'resources':
        tags.extend(random.sample(resource_tags, random.randint(1, 3)))
    else:  # archives
        tags.extend(random.sample(archive_tags, random.randint(1, 3)))
    
    # Add GTD context
    tags.append(random.choice(gtd_tags))
    
    return tags

def generate_filename(topic, index):
    """Generate a filename from topic"""
    # Replace special characters and spaces with underscores
    safe_topic = re.sub(r'[^\w\s-]', '', topic)
    safe_topic = re.sub(r'[\s/]+', '_', safe_topic)
    return f"{safe_topic}_{index}.md"

def generate_front_matter(title, tags):
    """Generate YAML front matter"""
    data = {
        'title': title,
        'date': (datetime.now() - timedelta(days=random.randint(0, 365))).strftime('%Y-%m-%d %H:%M:%S'),
        'tags': tags,
        'status': random.choice(['active', 'in_progress', 'completed', 'on_hold'])
    }
    return yaml.dump(data, allow_unicode=True)

def generate_test_files(base_dir, num_files=40):
    """Generate test markdown files"""
    categories = ['projects', 'areas', 'resources', 'archives']
    
    # Create base directory if it doesn't exist
    if not os.path.exists(base_dir):
        os.makedirs(base_dir)
    
    # Generate files
    for i in range(num_files):
        # Select random topic and category
        topic = random.choice(topics)
        category = random.choice(categories)
        
        # Generate content
        title = f"{topic} {i+1}"
        tags = generate_tags(category)
        content = random.choice(content_templates).format(title=title, topic=topic.lower())
        front_matter = generate_front_matter(title, tags)
        
        # Combine front matter and content
        full_content = f"---\n{front_matter}---\n\n{content}"
        
        # Write to file
        filename = generate_filename(topic, i+1)
        filepath = os.path.join(base_dir, filename)
        
        with open(filepath, 'w') as f:
            f.write(full_content)
        
        print(f"Generated: {filename}")
        print(f"Category: {category}")
        print(f"Tags: {tags}\n")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) != 2:
        print("Usage: python generate_test_files.py <target_directory>")
        sys.exit(1)
    
    target_dir = sys.argv[1]
    generate_test_files(target_dir)
    print(f"\nGenerated 40 test files in {target_dir}")
