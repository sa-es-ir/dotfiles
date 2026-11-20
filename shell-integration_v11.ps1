# Shell Integration — non-invasive prompt wrapper
# Emits OSC 133 (command marks / exit code) and OSC 9;9 (CWD) escape
# sequences WITHOUT altering the visual appearance of the user's prompt.
#
# Compatible with Windows PowerShell 5.1+ and PowerShell 7+.
# Safe to source multiple times (idempotent guard).

if (-not $Global:__ShellInteg_Installed) {

    # ── Escape characters (PS 5.1 doesn't support `e / `a literals) ──
    $Global:__ShellInteg_ESC = [char]0x1B   # ESC
    $Global:__ShellInteg_BEL = [char]0x07   # BEL (OSC string terminator)

    # ── Snapshot the user's current prompt before we touch it ──────────
    $Global:__ShellInteg_OriginalPrompt = $function:prompt
    $Global:__ShellInteg_LastHistoryId  = -1
    $Global:__ShellInteg_LastErrorRecord = $Error[0]
    $Global:__ShellInteg_LastSubmittedLine = $null
    $Global:__ShellInteg_PrevPrompt = $null
    $Global:__ShellInteg_Rendering = $false
    $Global:__ShellInteg_CanInspectErrors =
        $ExecutionContext.SessionState.LanguageMode -eq 'FullLanguage'
    $Global:__ShellInteg_Installed      = $true

    # PowerShell 7 drops parser failures before prompt runs, leaving no
    # observable status there. Retain the submitted line at the PSReadLine
    # boundary without changing what is returned to the engine.
    #
    # This boundary is also where we re-arm (see __ShellInteg_Rearm): it runs
    # once per command, BEFORE the user's command executes, so it cannot
    # disturb the $? that the next prompt reads.
    if ($Global:__ShellInteg_CanInspectErrors -and (Test-Path Function:\PSConsoleHostReadLine)) {
        function Global:__ShellInteg_GetResumeTarget {
            param([string]$line)
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput(
                $line, [ref]$tokens, [ref]$parseErrors)
            if ($parseErrors.Count -ne 0 -or $null -eq $ast.EndBlock -or
                $ast.BeginBlock -or $ast.ProcessBlock -or $ast.ParamBlock -or
                $ast.EndBlock.Statements.Count -ne 1) { return }
            $pipeline = $ast.EndBlock.Statements[0]
            if ($pipeline -isnot [System.Management.Automation.Language.PipelineAst] -or
                $pipeline.PipelineElements.Count -ne 1) { return }
            if ($pipeline.PSObject.Properties['Background'] -and $pipeline.Background) { return }
            $command = $pipeline.PipelineElements[0]
            if ($command -isnot [System.Management.Automation.Language.CommandAst] -or
                $command.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Dot) { return }
            if ($command.GetCommandName() -notmatch '^(?:.*[\\/])?(copilot|claude|gemini|codex|opencode|agy)(?:\.(?:exe|cmd|bat))?$') { return }
            $resumeAgent = $Matches[1].ToLowerInvariant()
            if ($resumeAgent -eq 'agy') { $resumeAgent = 'antigravity' }
            $arguments = @()
            for ($i = 1; $i -lt $command.CommandElements.Count; $i++) {
                $element = $command.CommandElements[$i]
                if ($element -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { return }
                $arguments += $element
            }
            $resumeSession = $null
            if ($resumeAgent -eq 'codex') {
                if ($arguments.Count -lt 2 -or
                    $arguments[0].StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::BareWord -or
                    $arguments[0].Value -cne 'resume') { return }
                $resumeSession = $arguments[1].Value
            }
            else {
                $flag = if ($resumeAgent -eq 'opencode') { '--session' }
                        elseif ($resumeAgent -eq 'antigravity') { '--conversation' }
                        else { '--resume' }
                for ($i = 0; $i -lt $arguments.Count; $i++) {
                    # Quoted IDs are allowed, but a wholly quoted argument is
                    # not a resume flag. Preserve the AST's quote boundary.
                    if ($arguments[$i].StringConstantType -ne [System.Management.Automation.Language.StringConstantType]::BareWord) { continue }
                    $argument = $arguments[$i].Value
                    if ($argument -ceq '--') { break }
                    if ($argument -ceq $flag) {
                        if ($null -ne $resumeSession -or $i + 1 -ge $arguments.Count) { return }
                        $resumeSession = $arguments[++$i].Value
                    }
                    elseif ($argument.StartsWith($flag + '=', [StringComparison]::Ordinal)) {
                        if ($null -ne $resumeSession) { return }
                        $resumeSession = $argument.Substring($flag.Length + 1)
                    }
                }
            }
            if ($null -eq $resumeSession -or $resumeSession.Length -gt 256 -or
                $resumeSession.StartsWith('-', [StringComparison]::Ordinal) -or
                $resumeSession -notmatch '\A[A-Za-z0-9_.:-]+\z' -or
                $resumeSession.StartsWith('sidekick-', [StringComparison]::Ordinal)) { return }
            return @{ Agent = $resumeAgent; SessionId = $resumeSession }
        }

        $Global:__ShellInteg_OriginalPSConsoleHostReadLine = $function:PSConsoleHostReadLine
        function Global:PSConsoleHostReadLine {
            __ShellInteg_Rearm
            $line = & $Global:__ShellInteg_OriginalPSConsoleHostReadLine @args
            $Global:__ShellInteg_LastSubmittedLine =
                if ($line -is [string]) { $line } else { $null }
            if ($line -is [string]) {
                $resume = __ShellInteg_GetResumeTarget $line
                if ($null -ne $resume) {
                    $resumeMark = '{0}]9001;Resume;{1};{2}{3}' -f
                        $Global:__ShellInteg_ESC, $resume.Agent, $resume.SessionId,
                        $Global:__ShellInteg_BEL
                    [Console]::Write($resumeMark)
                }
            }
            return $line
        }
    }

    function Global:__ShellInteg_GetLastExitCode {
        # $? still reflects the *user's* last command here because this
        # is the very first call inside the prompt function.
        if ($? -eq $True) { return 0 }
        # $? is False -> the last command failed. Preserve a real non-zero
        # native exit code. PowerShell-level errors leave the previous value
        # untouched, while command-not-found can leave it null because no
        # native process started; zero/null therefore use a numeric sentinel.
        if ($null -ne $LastExitCode -and $LastExitCode -ne 0) {
            return $LastExitCode
        }
        return -1
    }

    function prompt {
        # ── Capture exit code FIRST — before anything else can clobber $? ──
        $gle           = $(__ShellInteg_GetLastExitCode)

        # A prompt module may CHAIN rather than replace: it captures the
        # current prompt (ours) and calls it from inside its own. Once we
        # adopt it, delegating calls us back. Serve the prompt it displaced
        # so its text survives, instead of recursing.
        if ($Global:__ShellInteg_Rendering) {
            if ($Global:__ShellInteg_PrevPrompt) {
                return (& $Global:__ShellInteg_PrevPrompt)
            }
            # Nothing displaced left to serve. Return an empty string rather
            # than inventing prompt text: this wrapper never contributes
            # visible output of its own, and the chaining module renders its
            # own text around whatever we return.
            return ''
        }

        try {
            $submittedLine = $Global:__ShellInteg_LastSubmittedLine
            $errorRecord   = $Error[0]
            $entry         = Get-History -Count 1
            $loc           = $executionContext.SessionState.Path.CurrentLocation
            $E             = $Global:__ShellInteg_ESC
            $B             = $Global:__ShellInteg_BEL

            $prefix = ''
            $suffix = ''

            # ── Previous command finished (OSC 133;D with exit code) ──
            $historyAdvanced = $entry -and $entry.Id -ne $Global:__ShellInteg_LastHistoryId
            $newErrorRecord = $Global:__ShellInteg_CanInspectErrors -and
                $null -ne $errorRecord -and
                -not [object]::ReferenceEquals($errorRecord, $Global:__ShellInteg_LastErrorRecord)
            $inputHadParserError = $false
            if ($Global:__ShellInteg_CanInspectErrors -and
                $gle -eq 0 -and
                $null -ne $submittedLine -and
                ($newErrorRecord -or -not $historyAdvanced)) {
                $tokens = $null
                $parseErrors = $null
                [void][System.Management.Automation.Language.Parser]::ParseInput(
                    $submittedLine,
                    [ref]$tokens,
                    [ref]$parseErrors)
                $inputHadParserError = $parseErrors.Count -gt 0
            }
            if ($inputHadParserError -and $gle -eq 0) {
                $gle = -1
            }
            $newUntrackedError = -not $historyAdvanced -and $gle -ne 0 -and $newErrorRecord
            if ($historyAdvanced -or $newUntrackedError -or $inputHadParserError) {
                $prefix += "${E}]133;D;${gle}${B}"
            }

            # ── Prompt started (OSC 133;A) ──
            $prefix += "${E}]133;A${B}"

            # ── Report current working directory (OSC 9;9) ──
            $prefix += "${E}]9;9;`"${loc}`"${B}"

            # ── Report shell identity (OSC 9001;ShellType) ──
            # Emitted every prompt so the terminal always knows which shell owns
            # the pane, even after a nested shell (e.g. wsl) exits and PowerShell
            # repaints its prompt. PSEdition 'Core' is pwsh 7+, 'Desktop' is
            # Windows PowerShell 5.1.
            $shellName = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
            $prefix += "${E}]9001;ShellType;${shellName};$($PSVersionTable.PSVersion)${B}"

            # ── Prompt ended, command input starts (OSC 133;B) ──
            $suffix = "${E}]133;B${B}"

            # ── Restore a success/failure signal for the prompt we wrap ──
            # Our work above has overwritten $?, so a prompt that reads it (Oh My
            # Posh's status segment, starship, posh-git) would wrongly see success.
            # $? cannot be assigned, but it mirrors the last statement: looking up
            # a variable that does not exist fails WITHOUT touching $Error, and a
            # trivial assignment succeeds. This must be the statement immediately
            # before the delegation.
            #
            # The value restored is derived from $gle, not the literal $? the
            # engine had: parser-error detection above can turn a $?-true command
            # into $gle -1. That is deliberate - $gle is the same failure signal
            # reported in OSC 133;D, so the wrapped prompt and the terminal agree
            # on whether the command failed.
            $Global:__ShellInteg_Rendering = $true
            try {
            if ($gle -eq 0) { $null = $true }
            else { Get-Variable '__ShellInteg_NoSuchVariable__' -ErrorAction Ignore }
            # ── Delegate to the user's ORIGINAL prompt — visual output is theirs ──
            # Failures are caught HERE, at the delegation, so the wrapped prompt
            # is invoked exactly once per render. Letting it escape to the outer
            # catch would run it a second time and duplicate its side effects.
            # An empty result is correct: the host then supplies its own prompt.
            try     { $originalOutput = & $Global:__ShellInteg_OriginalPrompt }
            catch   { $originalOutput = '' }
            }
            finally { $Global:__ShellInteg_Rendering = $false }

            $Global:__ShellInteg_LastHistoryId = if ($entry) { $entry.Id } else { -1 }
            $Global:__ShellInteg_LastErrorRecord = $Error[0]
            $Global:__ShellInteg_LastSubmittedLine = $null

            return "${prefix}${originalOutput}${suffix}"
            }
        catch {
            # FAIL SAFE for failures in OUR OWN code above (Get-History, the
            # parser probe, string building). The wrapped prompt has its own
            # catch at the delegation, so reaching here means it has NOT yet
            # been invoked for this render - delegating now keeps it at exactly
            # one invocation.
            #
            # The reentrancy flag must be held here too. The normal path clears
            # it in its finally before this catch runs, so an adopted CHAINING
            # prompt would call back into us with the flag false and recurse
            # until the engine's call-depth limit - the very cycle the guard
            # above exists to prevent.
            $Global:__ShellInteg_Rendering = $true
            try { return (& $Global:__ShellInteg_OriginalPrompt) }
            catch {
                # The wrapped prompt itself threw. Return an empty string and
                # let the HOST fall back to its own built-in prompt. Do not
                # fabricate one: this wrapper never alters the visible prompt,
                # and a hand-rolled "PS <cwd>> " is only an imitation of the
                # real default, which differs by host and edition.
                return ''
            }
            finally { $Global:__ShellInteg_Rendering = $false }
        }
    }

    # Remember our own prompt scriptblock so re-arming can recognise it by
    # reference. Created once per session: re-creating it would make the
    # previous copy look like a third-party takeover.
    $Global:__ShellInteg_Wrapper = $function:prompt
}

# Any prompt renderer loaded AFTER us (Oh My Posh, starship, a module) replaces
# our wrapper and silently removes shell integration. Detect that by object
# identity, adopt the newcomer as the prompt we wrap, and reinstall ourselves.
# Runs on every source and once per command from the PSReadLine boundary.
function Global:__ShellInteg_Rearm {
    # No wrapper of our own to install. This happens when an OLDER version of
    # this script is already installed in the session: it set
    # __ShellInteg_Installed, so the block above was skipped and never created
    # our wrapper. Do nothing. Installing a null would clobber `prompt`, and
    # adopting the older version's wrapper as the prompt we wrap would make it
    # delegate to itself and overflow the call stack. The upgrade completes in
    # the next shell, which sources only this version.
    if ($null -eq $Global:__ShellInteg_Wrapper) { return }

    # Identity is compared with -eq rather than a static reference-equality
    # method. This function is called at script load and, when the readline
    # wrapper is installed, once per command. Under Constrained Language Mode a
    # static method call raises "Method invocation is supported only on core
    # types", which aborts the enclosing script even from inside try/catch -
    # breaking profile sourcing or the input path. ScriptBlock does not override
    # Equals, so -eq is reference identity here (verified: two script blocks with
    # identical text compare False), and the operator is permitted under
    # Constrained Language Mode.
    #
    # Scope of that: -eq makes this function SAFE to invoke under Constrained
    # Language Mode. It does not by itself make re-arming active there - the
    # readline wrapper above is gated on $Global:__ShellInteg_CanInspectErrors,
    # which is false in that mode, so the per-command driver is not installed and
    # integration degrades to "marks work, no self-healing after a takeover".
    $current = $function:prompt
    if ($null -eq $current) { return }
    if ($current -eq $Global:__ShellInteg_Wrapper) { return }

    # Best-effort. This runs from PSConsoleHostReadLine, so a throw here would
    # break the input path, and at script load, where it would break profile
    # sourcing. `prompt` can legitimately be ReadOnly or Constant in a hardened
    # profile, which makes Set-Item raise SessionStateUnauthorizedAccessException.
    # Shell integration is a convenience; never let it take the shell down.
    try {
        if ($current -ne $Global:__ShellInteg_OriginalPrompt) {
            # Retain the renderer being displaced, in case the newcomer chains
            # back into us.
            $Global:__ShellInteg_PrevPrompt = $Global:__ShellInteg_OriginalPrompt
            $Global:__ShellInteg_OriginalPrompt = $current
        }
        Set-Item Function:\global:prompt $Global:__ShellInteg_Wrapper -ErrorAction Stop
    }
    catch {
        # Leave whatever prompt is installed alone; try again next command.
    }
}

__ShellInteg_Rearm
