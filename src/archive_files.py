import re
from datetime import datetime

def archive_versioned_files(zone_path: str, archive_path: str):
    """
    For landing zones (like SFTP): Keeps the newest file of each type based on timestamp,
    and moves older files to the archive path.
    """
    try:
        files = dbutils.fs.ls(zone_path)
        file_groups = {}
        
        # Regex to extract base name and timestamp (e.g., customers_src_20042026100105.csv)
        pattern = re.compile(r"(.+)_(\d{14})\.csv$")
        
        for file in files:
            # Skip directories
            if file.isDir():
                continue
                
            match = pattern.search(file.name)
            if match:
                base_name = match.group(1)       
                timestamp_str = match.group(2)   
                
                file_time = datetime.strptime(timestamp_str, "%d%m%Y%H%M%S")
                
                if base_name not in file_groups:
                    file_groups[base_name] = []
                
                file_groups[base_name].append({
                    "file_name": file.name,
                    "path": file.path,
                    "timestamp": file_time
                })

        # Process each group to find the latest file and archive the rest
        for base_name, file_list in file_groups.items():
            file_list.sort(key=lambda x: x["timestamp"], reverse=True)
            
            # Keep the newest file
            latest_file = file_list[0]
            print(f"✅ Keeping active file: {latest_file['file_name']}")
            
            # Move all older files to the archive zone
            older_files = file_list[1:]
            for old_file in older_files:
                source = old_file["path"]
                destination = f"{archive_path}{old_file['file_name']}"
                
                print(f"📦 Archiving old version: {old_file['file_name']} -> {archive_path}")
                dbutils.fs.mv(source, destination)

    except Exception as e:
        # Fails gracefully if the folder doesn't exist yet
        if "java.io.FileNotFoundException" in str(e):
            print(f"ℹ️ Zone {zone_path} does not exist yet. Skipping.")
        else:
            print(f"🚨 ALERT: Archival process failed for zone {zone_path}. Error: {str(e)}")

def archive_all_files(zone_path: str, archive_path: str):
    """
    For processing zones (like Bronze): Moves ALL files to a timestamped archive 
    folder after processing to prevent the pipeline from reading them twice.
    """
    try:
        files = dbutils.fs.ls(zone_path)
        
        # Create a timestamped folder to keep archives organized
        timestamp_folder = datetime.now().strftime('%Y-%m-%d_%H-%M-%S')
        target_archive_dir = f"{archive_path}{timestamp_folder}/"
        
        files_moved = False
        
        for file in files:
            if file.isDir():
                continue
                
            source = file.path
            destination = f"{target_archive_dir}{file.name}"
            
            print(f"🧹 Clearing processed file: {file.name} -> {target_archive_dir}")
            dbutils.fs.mv(source, destination)
            files_moved = True
            
        if not files_moved:
            print(f"ℹ️ No files found to clean in {zone_path}.")
            
    except Exception as e:
        if "java.io.FileNotFoundException" in str(e):
            print(f"ℹ️ Zone {zone_path} does not exist yet. Skipping.")
        else:
            print(f"🚨 ALERT: Full archival failed for zone {zone_path}. Error: {str(e)}")

# ==========================================
# --- Execution Block ---
# ==========================================
S3_BUCKET = "s3://retail-dwh-project-bucket"
archive_destination = f"{S3_BUCKET}/archive/"

print("--- Starting Data Warehouse File Maintenance ---")

# 1. Clean the Landing Zone (Keep the newest files)
sftp_zone = f"{S3_BUCKET}/sftp/"
print(f"\nScanning Landing Zone: {sftp_zone}")
archive_versioned_files(sftp_zone, archive_destination)

# 2. Clean the Bronze Zone (Move EVERYTHING so tomorrow starts fresh)
bronze_zone = f"{S3_BUCKET}/bronze/"
print(f"\nScanning Bronze Zone: {bronze_zone}")
archive_all_files(bronze_zone, archive_destination)

# NOTE: Silver and Gold are explicitly excluded from this script.
# Databricks manages those Delta files automatically.
# To clean old data from Silver/Gold, run this SQL command instead:
# VACUUM silver.DimProduct RETAIN 168 HOURS;

print("\n✅ File maintenance complete!")