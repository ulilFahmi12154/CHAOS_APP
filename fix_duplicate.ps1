# Script untuk menghapus duplicate method _buildFasePertumbuhanCard di home_screen.dart
$filePath = "d:\.Semester 5\PEMROGRAMAN MOBILE\CHAOS_APP\lib\screens\home_screen.dart"
$content = Get-Content $filePath -Raw

# Cari posisi method kedua (duplicate) dan hapus
$pattern = '(?s)(  Widget _buildFasePertumbuhanCard\(\) \{.*?^\  \})'
$matches = [regex]::Matches($content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)

if ($matches.Count -ge 2) {
    Write-Host "Found $($matches.Count) methods, removing duplicate..."
    # Hapus match kedua
    $secondMatch = $matches[1]
    $before = $content.Substring(0, $secondMatch.Index)
    $after = $content.Substring($secondMatch.Index + $secondMatch.Length)
    $newContent = $before + $after
    Set-Content $filePath $newContent -NoNewline
    Write-Host "Duplicate removed successfully!"
} else {
    Write-Host "No duplicate found or pattern doesn't match"
}
