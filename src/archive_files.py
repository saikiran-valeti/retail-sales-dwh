import re
from datetime import datetime

def extract_date_from_filename(filename: str):
    """
    Extracts date from filename pattern: tablename_src_DDMMYYYYHHMMSS.csv
    Returns datetime.date object or None if pattern doesn't match.
    """
    # Pattern to match: _src_DDMMYYYYHHMMSS.csv (capture DDMMYYYY)
    pattern = r'_src_(\d{8})\d{6}\.csv$'
    match = re.search(pattern, filename)
    
    if match:
        date_str = match.group(1)  # DDMMYYYY
        try:
            # Parse DDMMYYYY format
            file_date = datetime.strptime(date_str, '%d%m%Y').date()
            return file_date
        except ValueError:
            return None
    return None

def archive_sftp_files(sftp_path: str, archive_path: str, timestamp_folder: str):
    """
    Moves OLD files from the SFTP landing zone to a timestamped 
    archive folder under raw/ subdirectory when NEW files are detected. 
    Keeps new files in the landing zone for processing.
    
    Date detection is based on filename pattern (tablename_src_DDMMYYYYHHMMSS.csv).
    Files are compared against each other - the newest file(s) are kept, older ones archived.
    """
    try:
        files = dbutils.fs.ls(sftp_path)
        
        if not files:
            print(f"ℹ️ No files found in {sftp_path}. SFTP zone is empty.")
            return False
        
        # Collect all valid files with their dates
        valid_files = []
        skipped_files = []
        
        for file in files:
            if file.isDir():
                continue
            
            # Extract date from filename
            file_date = extract_date_from_filename(file.name)
            
            if file_date is None:
                # File doesn't match expected pattern - skip it
                skipped_files.append(file)
                print(f"⚠️ Skipping {file.name} - doesn't match expected pattern")
                continue
            
            valid_files.append((file, file_date))
        
        if not valid_files:
            print(f"ℹ️ No valid files found in {sftp_path}.")
            return False
        
        if len(valid_files) == 1:
            print(f"ℹ️ Only one file found ({valid_files[0][0].name}). Nothing to archive.")
            return False
        
        # Find the newest date among all files
        newest_date = max(file_date for _, file_date in valid_files)
        
        # Separate files into new (newest date) and old (older dates)
        new_files = [(file, file_date) for file, file_date in valid_files if file_date == newest_date]
        old_files = [(file, file_date) for file, file_date in valid_files if file_date < newest_date]
        
        if not old_files:
            print(f"✅ All files are from the same date ({newest_date.strftime('%Y-%m-%d')}). No old files to archive.")
            return False
        
        # Create raw/ subdirectory for SFTP files
        target_archive_dir = f"{archive_path}{timestamp_folder}/raw/"
        
        print(f"📦 Newest file date: {newest_date.strftime('%Y-%m-%d')} ({len(new_files)} file(s))")
        print(f"📦 Archiving {len(old_files)} older file(s) to raw/...")
        
        # Archive only old files to raw/ folder
        for file, file_date in old_files:
            source = file.path
            destination = f"{target_archive_dir}{file.name}"
            
            print(f"   📦 Archiving: {file.name} (date: {file_date.strftime('%Y-%m-%d')}) -> archive/{timestamp_folder}/raw/")
            dbutils.fs.mv(source, destination)
        
        print(f"✅ Archived {len(old_files)} old file(s) to raw/. Kept {len(new_files)} newest file(s) in landing zone.")
        return True
            
    except Exception as e:
        if "java.io.FileNotFoundException" in str(e):
            print(f"ℹ️ Zone {sftp_path} does not exist yet. Skipping.")
            return False
        else:
            print(f"🚨 ALERT: SFTP archival process failed. Error: {str(e)}")
            return False

# ==========================================
# --- Execution Block ---
# ==========================================
S3_BUCKET = "s3://retail-dwh-project-bucket"
sftp_zone = f"{S3_BUCKET}/sftp/"
archive_destination = f"{S3_BUCKET}/archive/"

# Create a single timestamp for this archival run
timestamp_folder = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')

print("--- Starting SFTP Archival Process ---")
print(f"Archive location: {archive_destination}{timestamp_folder}/")

# Archive SFTP files to raw/ subfolder
print("\nProcessing SFTP files...")
sftp_archived = archive_sftp_files(sftp_zone, archive_destination, timestamp_folder)

print("\n✅ Archival process complete!")
