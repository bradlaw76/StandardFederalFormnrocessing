@{
    # Core solution identifiers
    SolutionName = "VAFormExtractionDemo"

    # Optional explicit target environment URL.
    # If empty, scripts use the active PAC auth profile environment.
    EnvironmentUrl = ""

    # Artifact locations
    ArtifactRoot = "artifacts/v2"
    BaselineFolder = "baseline"
    CandidateFolder = "candidate"

    # File names
    BaselineManagedZip = "VAFormExtractionDemo_v1_baseline_managed.zip"
    BaselineUnmanagedZip = "VAFormExtractionDemo_v1_baseline_unmanaged.zip"
    CandidateManagedZip = "VAFormExtractionDemo_v2_candidate_managed.zip"
    CandidateUnmanagedZip = "VAFormExtractionDemo_v2_candidate_unmanaged.zip"

    # Deployment behavior
    MaxAsyncWaitMinutes = 60
    PublishChangesOnImport = $true
    ForceOverwriteOnImport = $true
    ActivatePluginsOnImport = $false

    # Optional deployment settings json path for connection refs and env vars
    SettingsFile = ""
}
