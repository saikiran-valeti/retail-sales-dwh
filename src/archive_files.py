import re
from datetime import datetime

def archive_old_files(zone_path: str, archive_path: str):
    """
    Scans an S3 zone, identifies the latest file based on the timestamp,
    and moves older files to the archive path.
    """
    try:
        # List all files in the current zone
        files = dbutils.fs.ls(zone_path)
        file_groups = {}
        
        # Regex to extract base name and timestamp from filenames like: customers_src_20042026100105.csv
        pattern = re.compile(r"(.+)_(\d{14})\.csv$")
        
        for file in files:
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
                
                print(f"📦 Archiving: {old_file['file_name']} -> {archive_path}")
                dbutils.fs.mv(source, destination)

    except Exception as e:
        print(f"🚨 ALERT: Archival process failed for zone {zone_path}. Error: {str(e)}")
        raise e

# --- Execution ---
S3_BUCKET = "s3://retail-dwh-project-bucket"
archive_destination = f"{S3_BUCKET}/archive/"

# Updated to reflect the Medallion Architecture zones
zones_to_clean = [
    f"{S3_BUCKET}/sftp/", 
    f"{S3_BUCKET}/bronze/", 
    f"{S3_BUCKET}/silver/",
    f"{S3_BUCKET}/gold/"
]

for zone in zones_to_clean:
    print(f"\nScanning Zone: {zone}")
    archive_old_files(zone, archive_destination)