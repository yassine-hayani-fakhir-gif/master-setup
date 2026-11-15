function Initialize-MasterDashboardLayout($Window,$Canvas,$Header) {
    $baseline=[double]$Canvas.Width
    $items=@($Canvas.Controls | ForEach-Object {
        [pscustomobject]@{Control=$_;X=$_.Left;Width=$_.Width}
    })
    # Nested content stretches inside each card; accents keep their original width.
    foreach($panel in @($Canvas.Controls | Where-Object {$_ -is [Windows.Forms.Panel] -and $_ -ne $Header})) {
        foreach($child in $panel.Controls) {
            if($child.Width -gt 10){$child.Anchor='Top,Left,Right'}
        }
    }
    foreach($child in $Header.Controls){
        if($child.Left -gt ($baseline/2)){$child.Anchor='Top,Right'}
    }
    $layout={
        if($Window.WindowState -eq 'Minimized'){return}
        $width=[Math]::Max($baseline,$Window.ClientSize.Width-[Windows.Forms.SystemInformation]::VerticalScrollBarWidth)
        $Canvas.SuspendLayout()
        $Canvas.Width=[int]$width
        foreach($item in $items){
            $item.Control.Left=[int]($item.X*$width/$baseline)
            $item.Control.Width=[int]($item.Width*$width/$baseline)
        }
        $Canvas.ResumeLayout()
        $Window.AutoScrollMinSize=New-Object Drawing.Size([int]$baseline,($Canvas.Height+16))
    }.GetNewClosure()
    $Window.Add_ClientSizeChanged($layout)
    & $layout
}
