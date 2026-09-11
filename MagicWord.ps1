# ============================================================
#  Jurassic Park "magic word" prank - WinForms full-screen
#  Drop this next to magicword.wav and run it.
# ============================================================

# ---------- CONFIG ----------
$ThePassword = "dinosaur"     # the magic word
$MaxTries    = 6              # auto-closes after this many wrong tries
# ----------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---- crank system volume to max ----
# No clean native call to set an absolute level, so we send the
# "volume up" key many times; Windows caps at max, so this floors it up.
Add-Type -Name VolKeys -Namespace Win32 -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, System.UIntPtr dwExtraInfo);
'@
function Max-Volume {
    $VK_VOLUME_UP = 0xAF
    for ($i = 0; $i -lt 50; $i++) {
        [Win32.VolKeys]::keybd_event($VK_VOLUME_UP, 0, 0, [System.UIntPtr]::Zero)   # key down
        [Win32.VolKeys]::keybd_event($VK_VOLUME_UP, 0, 2, [System.UIntPtr]::Zero)   # key up
    }
}
Max-Volume

# resolve the folder this script lives in, then the wav next to it
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WavPath   = Join-Path $ScriptDir "magicword.wav"

# audio player (SoundPlayer - the method already proven to work)
$player = $null
if (Test-Path $WavPath) {
    $player = New-Object System.Media.SoundPlayer $WavPath
}
function Play-Sting {
    if ($player) { try { $player.Play() } catch {} }
    else { [System.Media.SystemSounds]::Hand.Play() }
}

$script:Tries = 0
$taunts = @(
    "ah ah ah! you didn't say the magic word!",
    "ah ah ah! you didn't say the magic word!",
    "nuh uh uh! still no magic word...",
    "come on, i said the MAGIC word.",
    "you really don't know it, do you?",
    "last one... then i'm outta here."
)

# ---------- form ----------
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.WindowState     = 'Maximized'
$form.TopMost         = $true
$form.BackColor       = [System.Drawing.Color]::Black
$form.KeyPreview      = $true
$form.Cursor          = [System.Windows.Forms.Cursors]::Default

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds

# ---- background grid (custom paint) ----
$gridOn = $true
$form.Add_Paint({
    param($sender,$e)
    $g = $e.Graphics
    $g.Clear([System.Drawing.Color]::Black)
    $alpha = if ($script:gridOn) { 150 } else { 60 }
    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($alpha,0,255,0)), 1
    $step = 44
    for ($x=0; $x -le $screen.Width; $x += $step) {
        $g.DrawLine($pen, $x, 0, $x, $screen.Height)
    }
    for ($y=0; $y -le $screen.Height; $y += $step) {
        $g.DrawLine($pen, 0, $y, $screen.Width, $y)
    }
    $pen.Dispose()
})

# blink timer for the grid
$script:gridOn = $true
$blink = New-Object System.Windows.Forms.Timer
$blink.Interval = 550
$blink.Add_Tick({ $script:gridOn = -not $script:gridOn; $form.Invalidate() })
$blink.Start()

# ---- finger ----
$finger = New-Object System.Windows.Forms.Label
$finger.Text = [char]::ConvertFromUtf32(0x261D)  # up-pointing index
$finger.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 60)
$finger.ForeColor = [System.Drawing.Color]::FromArgb(51,255,51)
$finger.BackColor = [System.Drawing.Color]::Transparent
$finger.AutoSize = $true
$form.Controls.Add($finger)

# wag the finger by nudging it left/right (simple, reliable)
$wagState = 0
$wag = New-Object System.Windows.Forms.Timer
$wag.Interval = 180
$wag.Add_Tick({
    $script:wagState = ($script:wagState + 1) % 2
    $dx = if ($script:wagState -eq 0) { -18 } else { 18 }
    $finger.Left = [int]($screen.Width/2 - $finger.Width/2 + $dx)
})
$wag.Start()

# ---- title ----
$title = New-Object System.Windows.Forms.Label
$title.Text = "ah ah ah!"
$title.Font = New-Object System.Drawing.Font("Courier New", 40, [System.Drawing.FontStyle]::Bold)
$title.ForeColor = [System.Drawing.Color]::FromArgb(51,255,51)
$title.BackColor = [System.Drawing.Color]::Transparent
$title.AutoSize = $true
$form.Controls.Add($title)

# ---- message ----
$msg = New-Object System.Windows.Forms.Label
$msg.Text = "you didn't say the magic word!"
$msg.Font = New-Object System.Drawing.Font("Courier New", 20)
$msg.ForeColor = [System.Drawing.Color]::FromArgb(191,251,191)
$msg.BackColor = [System.Drawing.Color]::Transparent
$msg.AutoSize = $true
$form.Controls.Add($msg)

# ---- password box ----
$pw = New-Object System.Windows.Forms.TextBox
$pw.UseSystemPasswordChar = $true
$pw.Font = New-Object System.Drawing.Font("Courier New", 22)
$pw.BackColor = [System.Drawing.Color]::FromArgb(0,24,0)
$pw.ForeColor = [System.Drawing.Color]::FromArgb(51,255,51)
$pw.BorderStyle = 'FixedSingle'
$pw.Width = 380
$pw.TextAlign = 'Center'
$form.Controls.Add($pw)

# ---- enter button ----
$btn = New-Object System.Windows.Forms.Button
$btn.Text = "Enter"
$btn.Font = New-Object System.Drawing.Font("Courier New", 18)
$btn.ForeColor = [System.Drawing.Color]::FromArgb(51,255,51)
$btn.BackColor = [System.Drawing.Color]::FromArgb(0,24,0)
$btn.FlatStyle = 'Flat'
$btn.Width = 160
$btn.Height = 50
$form.Controls.Add($btn)

# ---- image (to the right of the password box) ----
$imgPath = Join-Path $ScriptDir "bg.jpg"
$pic = New-Object System.Windows.Forms.PictureBox
$pic.Width  = 288      # ~3 inches at 96 DPI; adjust to taste
$pic.Height = 288
$pic.SizeMode = 'Zoom' # fit the image within the box, keep aspect ratio
$pic.BackColor = [System.Drawing.Color]::Transparent
$picHasImage = $false
if (Test-Path $imgPath) {
    try {
        $pic.Image = [System.Drawing.Image]::FromFile($imgPath)
        $picHasImage = $true
    } catch { $picHasImage = $false }
}
if ($picHasImage) { $form.Controls.Add($pic) }

# ---- layout (everything stacked and centered; image below the button) ----
$gap = 24   # vertical space between the Enter button and the image
function Layout {
    $cx = [int]($screen.Width/2)
    $finger.Left = [int]($cx - $finger.Width/2); $finger.Top = [int]($screen.Height*0.12)
    $title.Left  = [int]($cx - $title.Width/2);  $title.Top  = [int]($screen.Height*0.12 + 110)
    $msg.Left    = [int]($cx - $msg.Width/2);     $msg.Top    = [int]($title.Top + 70)
    $pw.Left     = [int]($cx - $pw.Width/2);       $pw.Top     = [int]($msg.Top + 60)
    $btn.Left    = [int]($cx - $btn.Width/2);      $btn.Top     = [int]($pw.Top + 55)
    if ($picHasImage) {
        # image sits centered, directly below the Enter button
        $pic.Left = [int]($cx - $pic.Width/2)
        $pic.Top  = [int]($btn.Top + $btn.Height + $gap)
    }
}
$form.Add_Shown({ Layout; Play-Sting; $pw.Focus() })

# ---- password check logic ----
function Check-Pass {
    if ($pw.Text -eq $ThePassword) {
        $form.Close()
    } else {
        $script:Tries++
        Play-Sting
        if ($script:Tries -ge $MaxTries) {
            $msg.Text = "Fine. You win."
            Layout
            Start-Sleep -Milliseconds 600
            $form.Close()
        } else {
            $msg.Text = $taunts[$script:Tries]
            $pw.Clear()
            Layout
            $pw.Focus()
        }
    }
}

$btn.Add_Click({ Check-Pass })
$pw.Add_KeyDown({ if ($_.KeyCode -eq 'Enter') { Check-Pass } })
$form.Add_KeyDown({ if ($_.KeyCode -eq 'Escape' -or $_.KeyCode -eq 'J') { $form.Close() } })

[void]$form.ShowDialog()
if ($player) { $player.Dispose() }
