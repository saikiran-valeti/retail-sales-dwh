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
    archive folder under raw/ subdirectory when NEW files are uploaded. 
    Keeps new files in the landing zone for processing.
    
    Date detection is based on filename pattern (tablename_src_DDMMYYYYHHMMSS.csv),
    NOT file modification time.
    """
    try:
        files = dbutils.fs.ls(sftp_path)
        
        if not files:
            print(f"ℹ️ No files found in {sftp_path}. SFTP zone is empty.")
            return False
        
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
            return False
        
        if not old_files:
            print(f"✅ {len(new_files)} new file(s) uploaded today. No old files to archive.")
            return False
        
        # Create raw/ subdirectory for SFTP files
        target_archive_dir = f"{archive_path}{timestamp_folder}/raw/"
        
        print(f"📦 New files detected ({len(new_files)}). Archiving {len(old_files)} old file(s) to raw/...")
        
        # Archive only old files to raw/ folder
        for file, file_date in old_files:
            source = file.path
            destination = f"{target_archive_dir}{file.name}"
            
            print(f"   📦 Archiving: {file.name} (date: {file_date.strftime('%Y-%m-%d')}) -> archive/{timestamp_folder}/raw/")
            dbutils.fs.mv(source, destination)
        
        print(f"✅ Archived {len(old_files)} old file(s) to raw/. Kept {len(new_files)} new file(s) in landing zone.")
        return True
            
    except Exception as e:
        if "java.io.FileNotFoundException" in str(e):
            print(f"ℹ️ Zone {sftp_path} does not exist yet. Skipping.")
            return False
        else:
            print(f"🚨 ALERT: SFTP archival process failed. Error: {str(e)}")
            return False

def archive_processed_files(silver_path: str, gold_path: str, archive_path: str, timestamp_folder: str):
    """
    Archives processed dimension and fact tables from silver and gold layers 
    to a timestamped archive folder under processed/ subdirectory.
    
    Silver tables: DimCustomer, DimProduct, DimStore
    Gold tables: FactSales_v2
    """
    # Define which tables belong to which layer
    silver_tables = ['DimCustomer', 'DimProduct', 'DimStore']
    gold_tables = ['FactSales_v2']
    
    total_archived = 0
    
    # Archive Silver Layer tables
    try:
        print(f"   Checking Silver layer ({silver_path})...")
        files = dbutils.fs.ls(silver_path)
        
        tables_to_archive = []
        for file in files:
            if file.isDir():
                dir_name = file.name.rstrip('/')
                if dir_name in silver_tables:
                    tables_to_archive.append(('silver', file, dir_name))
        
        if tables_to_archive:
            target_archive_dir = f"{archive_path}{timestamp_folder}/processed/silver/"
            
            for layer, table, table_name in tables_to_archive:
                source = table.path
                destination = f"{target_archive_dir}{table_name}/"
                
                print(f"   📦 Archiving: {table_name} (silver) -> archive/{timestamp_folder}/processed/silver/")
                dbutils.fs.mv(source, destination)
                total_archived += 1
        else:
            print(f"   ℹ️ No silver tables found to archive.")
            
    except Exception as e:
        if "java.io.FileNotFoundException" in str(e):
            print(f"   ℹ️ Silver layer {silver_path} does not exist yet. Skipping.")
        else:
            print(f"   🚨 Silver layer archival failed. Error: {str(e)}")
    
    # Archive Gold Layer tables
    try:
        print(f"   Checking Gold layer ({gold_path})...")
        files = dbutils.fs.ls(gold_path)
        
        tables_to_archive = []
        for file in files:
            if file.isDir():
                dir_name = file.name.rstrip('/')
                if dir_name in gold_tables:
                    tables_to_archive.append(('gold', file, dir_name))
        
        if tables_to_archive:
            target_archive_dir = f"{archive_path}{timestamp_folder}/processed/gold/"
            
            for layer, table, table_name in tables_to_archive:
                source = table.path
                destination = f"{target_archive_dir}{table_name}/"
                
                print(f"   📦 Archiving: {table_name} (gold) -> archive/{timestamp_folder}/processed/gold/")
                dbutils.fs.mv(source, destination)
                total_archived += 1
        else:
            print(f"   ℹ️ No gold tables found to archive.")
            
    except Exception as e:
        if "java.io.FileNotFoundException" in str(e):
            print(f"   ℹ️ Gold layer {gold_path} does not exist yet. Skipping.")
        else:
            print(f"   🚨 Gold layer archival failed. Error: {str(e)}")
    
    if total_archived > 0:
        print(f"✅ Archived {total_archived} processed table(s) total.")
    else:
        print(f"ℹ️ No processed tables found to archive.")

# ==========================================
# --- Execution Block ---
# ==========================================
S3_BUCKET = "s3://retail-dwh-project-bucket"
sftp_zone = f"{S3_BUCKET}/sftp/"
silver_zone = f"{S3_BUCKET}/silver/"
gold_zone = f"{S3_BUCKET}/gold/"
archive_destination = f"{S3_BUCKET}/archive/"

# Create a single timestamp for this archival run
timestamp_folder = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')

print("--- Starting Archival Process ---")
print(f"Archive location: {archive_destination}{timestamp_folder}/")

# Archive SFTP files to raw/ subfolder
print("\n[1/2] Processing SFTP files...")
sftp_archived = archive_sftp_files(sftp_zone, archive_destination, timestamp_folder)

# Archive processed files from silver and gold layers
print("\n[2/2] Processing dimension/fact tables from silver and gold layers...")
archive_processed_files(silver_zone, gold_zone, archive_destination, timestamp_folder)

print("\n✅ Archival process complete!")
