@{
    # Core solution identifiers
    # Detected from pac solution list in active environment.
    SolutionName = "VAFormExtractionDemo"

    # Active PAC profile environment at setup time:
    # https://healthconnectcenter.crm.dynamics.com/
    EnvironmentUrl = "https://healthconnectcenter.crm.dynamics.com/"

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
