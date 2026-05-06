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

def archive_sftp_files(sftp_path: str, archive_path: str):
    """
    Moves OLD files from the SFTP landing zone to a timestamped 
    archive folder when NEW files are uploaded. Keeps new files 
    in the landing zone for processing.
    
    Date detection is based on filename pattern (tablename_src_DDMMYYYYHHMMSS.csv),
    NOT file modification time.
    """
    try:
        files = dbutils.fs.ls(sftp_path)
        
        if not files:
            print(f"ℹ️ No files found in {sftp_path}. SFTP zone is empty.")
            return
        
        # Get today's date (without time component)
        today = datetime.now().date()
        
        # Separate files into new (today) and old (before today)
        new_files = []
        old_files = []
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
            
            if file_date == today:
                new_files.append((file, file_date))
            else:
                old_files.append((file, file_date))
        
        # Only archive old files if there are new files uploaded today
        if not new_files:
            print(f"ℹ️ No new files uploaded today. Skipping archival.")
            if old_files:
                print(f"   ({len(old_files)} old file(s) remain in landing zone)")
            return
        
        if not old_files:
            print(f"✅ {len(new_files)} new file(s) uploaded today. No old files to archive.")
            return
        
        # Create a timestamped folder for archival
        timestamp_folder = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
        target_archive_dir = f"{archive_path}{timestamp_folder}/"
        
        print(f"📦 New files detected ({len(new_files)}). Archiving {len(old_files)} old file(s)...")
        
        # Archive only old files
        for file, file_date in old_files:
            source = file.path
            destination = f"{target_archive_dir}{file.name}"
            
            print(f"   📦 Archiving: {file.name} (date from filename: {file_date.strftime('%Y-%m-%d')}) -> archive/")
            dbutils.fs.mv(source, destination)
        
        print(f"✅ Archived {len(old_files)} old file(s). Kept {len(new_files)} new file(s) in landing zone.")
            
    except Exception as e:
        if "java.io.FileNotFoundException" in str(e):
            print(f"ℹ️ Zone {sftp_path} does not exist yet. Skipping.")
        else:
            print(f"🚨 ALERT: Archival process failed. Error: {str(e)}")

# ==========================================
# --- Execution Block ---
# ==========================================
S3_BUCKET = "s3://retail-dwh-project-bucket"
sftp_zone = f"{S3_BUCKET}/sftp/"
archive_destination = f"{S3_BUCKET}/archive/"

print("--- Starting SFTP Cleanup ---")
archive_sftp_files(sftp_zone, archive_destination)
print("✅ SFTP Cleanup complete!")
