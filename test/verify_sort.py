#!/usr/bin/env python3
import os
import yaml
import sys
from collections import defaultdict

def verify_sorting(vault_path):
    """Verify that files are sorted correctly based on their tags"""
    
    # Define tag categories
    project_tags = {'project', 'deadline', 'milestone', 'client', 'team', 'sprint', 'development'}
    area_tags = {'health', 'finance', 'career', 'learning', 'family', 'fitness', 'skills'}
    resource_tags = {'reference', 'article', 'book', 'tutorial', 'guide', 'template', 'research'}
    archive_tags = {'completed', 'archived', 'old', 'inactive', '2023', 'deprecated', 'historical'}
    
    # Track files and their locations
    files_by_category = defaultdict(list)
    misplaced_files = []
    
    # Check each PARA directory
    para_dirs = ['projects', 'areas', 'resources', 'archives']
    for para_dir in para_dirs:
        dir_path = os.path.join(vault_path, para_dir)
        if not os.path.exists(dir_path):
            print(f"Warning: {para_dir} directory doesn't exist")
            continue
            
        # Check each file in the directory
        for filename in os.listdir(dir_path):
            if not filename.endswith('.md'):
                continue
                
            filepath = os.path.join(dir_path, filename)
            try:
                with open(filepath, 'r') as f:
                    content = f.read()
                    # Extract YAML front matter
                    if content.startswith('---'):
                        _, yaml_content, _ = content.split('---', 2)
                        metadata = yaml.safe_load(yaml_content)
                        tags = set(map(str.lower, metadata.get('tags', [])))
                        
                        # Determine where file should be based on tags
                        tag_matches = {
                            'projects': len(tags & project_tags),
                            'areas': len(tags & area_tags),
                            'resources': len(tags & resource_tags),
                            'archives': len(tags & archive_tags)
                        }
                        
                        # Get directory with most matching tags
                        best_dir = max(tag_matches.items(), key=lambda x: x[1])[0]
                        
                        # If no tags match, should be in resources
                        if all(count == 0 for count in tag_matches.values()):
                            best_dir = 'resources'
                        
                        files_by_category[para_dir].append(filename)
                        
                        # Check if file is in the right place
                        if best_dir != para_dir:
                            misplaced_files.append({
                                'file': filename,
                                'current_dir': para_dir,
                                'suggested_dir': best_dir,
                                'tags': list(tags)
                            })
                            
            except Exception as e:
                print(f"Error processing {filename}: {str(e)}")
    
    # Print results
    print("\nSorting Results:")
    print("================")
    
    print("\nFiles by Category:")
    for category, files in files_by_category.items():
        print(f"\n{category.upper()} ({len(files)} files):")
        for file in sorted(files):
            print(f"  - {file}")
    
    if misplaced_files:
        print("\nPotentially Misplaced Files:")
        print("==========================")
        for file in misplaced_files:
            print(f"\n{file['file']}:")
            print(f"  Current: {file['current_dir']}")
            print(f"  Suggested: {file['suggested_dir']}")
            print(f"  Tags: {', '.join(file['tags'])}")
    else:
        print("\nAll files appear to be correctly sorted!")
    
    return len(misplaced_files) == 0

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python verify_sort.py <vault_path>")
        sys.exit(1)
        
    vault_path = sys.argv[1]
    if not os.path.isdir(vault_path):
        print(f"Error: {vault_path} is not a directory")
        sys.exit(1)
        
    success = verify_sorting(vault_path)
    sys.exit(0 if success else 1)
