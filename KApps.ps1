#########################################################################
# Author:   Kafej                                                       #
# E-mail:   kafej666@gmail.com                                          #
# LinkedIn: https://www.linkedin.com/in/mzbyl/                          #
# ver: Alpha 1.2.5          											#
#########################################################################

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$AssemblyLocation = Join-Path -Path $ScriptPath -ChildPath .\inc
foreach ($Assembly in (Get-ChildItem $AssemblyLocation -Filter *.dll)) {
    [System.Reflection.Assembly]::LoadFrom($Assembly.fullName) | out-null
}

function close-SplashScreen () {
    $hash.window.Dispatcher.Invoke("Normal",[action]{ $hash.window.close() })
    $Pwshell.EndInvoke($handle) | Out-Null
}

function Start-SplashScreen {
    $Pwshell.Runspace = $runspace
    $script:handle = $Pwshell.BeginInvoke() 
}

$hash = [hashtable]::Synchronized(@{})
$runspace = [runspacefactory]::CreateRunspace()
$runspace.ApartmentState = "STA"
$Runspace.ThreadOptions = "ReuseThread"
$runspace.Open()
$runspace.SessionStateProxy.SetVariable("hash",$hash) 
$Pwshell = [PowerShell]::Create()

$Pwshell.AddScript({
    $xml = [xml]@"
    <Window
    xmlns:Controls="clr-namespace:MahApps.Metro.Controls;assembly=MahApps.Metro"
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="WindowSplash" Title="KaLoading" WindowStyle="None" WindowStartupLocation="CenterScreen"
    Background="DarkSlateGray" ShowInTaskbar ="true" 
    Width="300" Height="120" ResizeMode = "NoResize" Topmost = "true">

    <Grid>	
        <Grid>
            <StackPanel Orientation="Vertical" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="5,5,5,5">
                <Label x:Name = "LoadingLabel"  Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="24" Margin = "0,0,0,0"/>
                <Controls:ProgressRing IsActive="True" Foreground="White" HorizontalAlignment="Center" Width="40" Height="40"/>
            </StackPanel>	
        </Grid>
    </Grid>
        
    </Window> 
"@

	$reader = New-Object System.Xml.XmlNodeReader $xml
	$hash.window = [Windows.Markup.XamlReader]::Load($reader)
	$hash.LoadingLabel = $hash.window.FindName("LoadingLabel")
	$hash.LoadingLabel.Content= "Loading"
	$hash.window.ShowDialog() 

}) | Out-Null

Start-SplashScreen

function LoadXaml ($filename){
    $XamlLoader=(New-Object System.Xml.XmlDocument)
    $XamlLoader.Load($filename)
    return $XamlLoader
}

$XamlMainWindow=LoadXaml($ScriptPath+"\inc\main.xaml")
$reader = (New-Object System.Xml.XmlNodeReader $XamlMainWindow)
$Form = [Windows.Markup.XamlReader]::Load($reader)

$XamlMainWindow.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")  | ForEach-Object {
  New-Variable  -Name $_.Name -Value $Form.FindName($_.Name) -Force
}

function wgetNew ($QuickSearch) {
	$SyncHash = [hashtable]::Synchronized(@{Window = $Form; Datagridmain = $Datagridmain; pbar = $pbar})
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Open()
    $Runspace.SessionStateProxy.SetVariable("SyncHash", $SyncHash)
    $Worker = [PowerShell]::Create().AddScript({
		Param ($QuickSearch)
		$Na = @()
		$version = @()
		$c = winget search
		$first, $si, $sii, $cc = $c
	
		$cc | ForEach-Object {
			$s = $_
			$t = $s -replace '\s\s',','
			$f = $t -replace '\.\.\.',','
			$f = $f -replace '\('
			$fi = $f.Split(',')[0]
	
			$w = $t -replace '\s',','
			$se = $w.Split(",")[-1]
	
			$r = $f -replace "$se",','
			$r = $r -replace '\s',','
	
			$Na += $fi
			$version += $se
		}
	
		$MaxLength = [Math]::Max($Na.Length, $version.Lenght)
	
		$rr = for ($li = 0; $li -lt $MaxLength; $li++) {
			[PSCustomObject]@{
				Name=$Na[$li]
				Version=$version[$li]
			}
		}
	
		if ($QuickSearch) {
			$columns = $rr | Select-Object -Property Name, Version | Where-Object {$_.Name -like "*$QuickSearch*"}
		} else {
			$columns = $rr | Select-Object -Property Name, Version
		}
	 
		$script:observableCollection = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
	
		$columns | ForEach-Object {
			$objArray = New-Object PSObject
			$objArray | Add-Member -type NoteProperty -name NaT -value $_."Name"
			$objArray | Add-Member -type NoteProperty -name Version -value $_."Version"
			$script:observableCollection.Add($objArray) | Out-Null
		}

        $SyncHash.Window.Dispatcher.Invoke([action]{$SyncHash.DataGridmain.ItemsSource=$Script:observableCollection})
        $SyncHash.Window.Dispatcher.Invoke([action]{$SyncHash.pbar.Visibility="Hidden"})
    }).AddArgument($QuickSearch)
    $Worker.Runspace = $Runspace
	$Worker.BeginInvoke()
}

$wpm.Add_Click({
    Start-Process "https://github.com/microsoft/winget-cli/releases/download/v0.1.4331-preview/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.appxbundle"
})

$gwpm.Add_Click({
    Start-Process "https://github.com/microsoft/winget-cli"
})

$ps.Add_Click({
    Start-Process "https://github.com/PowerShell/PowerShell/releases/download/v7.0.1/PowerShell-7.0.1-win-x64.msi"
})

$rl.Add_Click({
	$DataGridmain.ItemsSource = ''
	$pbar.Visibility="Visible"
    wgetNew
})

$cu.Add_Click({
    Start-Process mailto:michal.zbyl@gmail.com?subject=Kapps
})

Function Down($rowObj) {
    $DownName = $rowObj.Nat

	Start-Process cmd "/c winget install -e --name `"$DownName`"" -NoNewWindow
}

Function Delete($rowObj) {
    Start-Process Appwiz.cpl
}

[System.Windows.RoutedEventHandler]$EventonDataGrid = {

    $button =  $_.OriginalSource.Name
    $Script:resultObj = $DataGridmain.CurrentItem

    If ($button -match "Down") {
        Down -rowObj $resultObj
    }
    ElseIf ($button -match "Delete" ) {
        Delete -rowObj $resultObj
    }

}
$DataGridmain.AddHandler([System.Windows.Controls.Button]::ClickEvent, $EventonDataGrid)

$QuickLaunchBar.Add_KeyDown(
{
	$QuickSearch = $QuickLaunchBar.Text
	
	if ($_.Key -eq "Enter") 
	{
		$pbar.Visibility="Visible"
		if ($QuickSearch) {
			wgetNew $QuickSearch
		} else {
			wgetNew
		}
}})

wgetNew

$Form.Add_KeyDown({
	$Kch = [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftCtrl) -and [System.Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::F)
	if ($Kch -eq $True) {
		$QuickLaunchBar.Focus()
	}
})

$SyncHash = [hashtable]::Synchronized(@{Window = $Form})
$Runspace = [runspacefactory]::CreateRunspace()
$Runspace.ThreadOptions = "ReuseThread"
$Runspace.Open()
$Runspace.SessionStateProxy.SetVariable("SyncHash", $SyncHash)
$Worker = [PowerShell]::Create().AddScript({
		Start-Sleep 2
		$SyncHash.Window.Dispatcher.Invoke([action]{$SyncHash.Window.Topmost=$False})
})
$Worker.Runspace = $Runspace
$Worker.BeginInvoke()

$Form.Topmost = $True
$Form.Icon = "$AssemblyLocation\icon.ico"
$Icon.Source = "$AssemblyLocation\icon.ico"

close-SplashScreen

[void]$Form.ShowDialog()