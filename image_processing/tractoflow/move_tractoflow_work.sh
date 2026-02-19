#!/bin/bash

# Move Nextflow work directory and update symlinks

OLD_WORK="/home1/jasonkru/atri_code/processors/tractoflow/work"
NEW_WORK="/project2/jasonkru_1564/studies/ABCDS/tractoflow/tractoflow_qc_nf_work"
OUTPUT_DIR="/project2/jasonkru_1564/studies/ABCDS/tractoflow/tractoflow_qc_output"

echo "=== Moving Nextflow work directory ==="
echo "From: $OLD_WORK"
echo "To:   $NEW_WORK"

# Check if old work directory exists
if [ ! -d "$OLD_WORK" ]; then
    echo "Error: Source work directory does not exist: $OLD_WORK"
    exit 1
fi

# Check if new location already exists
if [ -d "$NEW_WORK" ]; then
    echo "Warning: Destination already exists: $NEW_WORK"
    read -p "Do you want to remove it and continue? (yes/no): " answer
    if [ "$answer" = "yes" ]; then
        rm -rf "$NEW_WORK"
    else
        echo "Aborting."
        exit 1
    fi
fi

# Move the work directory
echo "Moving work directory..."
mv "$OLD_WORK" "$NEW_WORK"

if [ $? -eq 0 ]; then
    echo "✓ Work directory moved successfully"
else
    echo "✗ Failed to move work directory"
    exit 1
fi

echo ""
echo "=== Updating symlinks in output directory ==="
echo "Output: $OUTPUT_DIR"

# Check if output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Warning: Output directory does not exist: $OUTPUT_DIR"
    exit 0
fi

# Count symlinks to update
total_symlinks=$(find "$OUTPUT_DIR" -type l | wc -l)
echo "Found $total_symlinks symlinks"

# Update each symlink
updated=0
failed=0

find "$OUTPUT_DIR" -type l | while read symlink; do
    target=$(readlink "$symlink")
    
    # Check if this symlink points to the old work directory
    if [[ "$target" == "$OLD_WORK"* ]]; then
        # Replace old path with new path
        new_target="${target/$OLD_WORK/$NEW_WORK}"
        
        # Update the symlink
        ln -sf "$new_target" "$symlink"
        
        if [ $? -eq 0 ]; then
            ((updated++))
            echo "✓ Updated: $symlink"
        else
            ((failed++))
            echo "✗ Failed: $symlink"
        fi
    fi
done

echo ""
echo "=== Summary ==="
echo "Total symlinks found: $total_symlinks"
echo "Updated: $updated"
echo "Failed: $failed"
echo ""
echo "Done! You can now resume your pipeline with:"
echo "nextflow run ... -work-dir $NEW_WORK -resume"
