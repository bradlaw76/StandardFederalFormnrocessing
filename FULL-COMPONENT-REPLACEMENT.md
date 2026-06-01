# Full Component Replacement

Copy everything inside this single block and replace your current component file.

```tsx
import React, { useEffect, useMemo, useState } from "react";
import {
    Text,
    DataGrid,
    DataGridHeader,
    DataGridBody,
    DataGridRow,
    DataGridCell,
    DataGridHeaderCell,
    TableCellLayout,
    createTableColumn,
    Input,
    Button,
} from "@fluentui/react-components";
import type {
    GeneratedComponentProps,
    vafe_extractionresult,
    vafe_d365writeevent,
    ReadableTableRow,
    QueryTableOptions,
} from "./RuntimeTypes";

type ExtractionRow = ReadableTableRow<vafe_extractionresult> & Record<string, unknown>;
type WriteEventRow = ReadableTableRow<vafe_d365writeevent> & Record<string, unknown>;

const langMap: Record<number, { code: string; name: string; isRtl: boolean }> = {
    1033: { code: "en-US", name: "English (United States)", isRtl: false },
};

const translations: Record<string, Record<string, string>> = {
    "en-US": {
        pageTitle: "D365 Extraction Results",
        totalExtractions: "Total extractions",
        successExtractions: "Successful extractions",
        searchPlaceholder: "Search extraction results...",
        reset: "Reset",
        noRecords: "No extraction results found.",
        stats: "Statistics",
        records: "Records",
        extractionId: "Extraction ID",
        formSubmissionId: "Form Submission",
        extractionStatus: "Extraction status",
        overallConfidence: "Overall confidence",
        modelVersion: "Model version",
        extractionTimestamp: "Extracted on",
        d365Status: "D365 status",
        d365RecordId: "D365 record",
        retryCount: "Retries",
        errorMessage: "Error",
        refresh: "Refresh",
    },
};

const getLanguage = () => {
    const uiLanguageId =
        (typeof Xrm !== "undefined" &&
            Xrm.Utility?.getGlobalContext()?.userSettings?.languageId) ||
        1033;
    return langMap[uiLanguageId]?.code || "en-US";
};

const getIsRTL = () => {
    const uiLanguageId =
        (typeof Xrm !== "undefined" &&
            Xrm.Utility?.getGlobalContext()?.userSettings?.languageId) ||
        1033;
    return langMap[uiLanguageId]?.isRtl || false;
};

const t = (key: string): string => {
    const language = getLanguage();
    return translations[language]?.[key] || translations["en-US"]?.[key] || key;
};

const useUserSettings = (dataApi: GeneratedComponentProps["dataApi"]) => {
    const [userSettings, setUserSettings] = useState<any>(null);

    useEffect(() => {
        const fetchUserSettings = async () => {
            const currentUserId = (typeof Xrm !== "undefined" &&
                Xrm.Utility?.getGlobalContext()?.userSettings?.userId)
                ?.replace("{", "")
                .replace("}", "");
            if (!currentUserId) return;

            const settings = await dataApi.retrieveRow("usersettings", {
                id: currentUserId,
                select: [
                    "uilanguageid",
                    "localeid",
                    "decimalsymbol",
                    "numberseparator",
                    "currencysymbol",
                    "dateformatstring",
                    "dateseparator",
                ],
            });

            setUserSettings(settings);
        };

        if (dataApi) fetchUserSettings();
    }, [dataApi]);

    return userSettings;
};

const formatDate = (value: unknown, userSettings: any): string => {
    if (!value) return "-";
    const date = new Date(String(value));
    if (Number.isNaN(date.getTime())) return "-";

    if (!userSettings) return date.toLocaleDateString(getLanguage());

    const sep = userSettings.dateseparator || "/";
    const fmt = (userSettings.dateformatstring || "MM/dd/yyyy")
        .replace("yyyy", date.getFullYear().toString())
        .replace("MM", String(date.getMonth() + 1).padStart(2, "0"))
        .replace("dd", String(date.getDate()).padStart(2, "0"))
        .replace("/", sep)
        .replace("/", sep);

    return fmt;
};

const formatNumber = (value: number, userSettings: any): string => {
    if (!Number.isFinite(value)) return "-";
    if (!userSettings) return new Intl.NumberFormat(getLanguage()).format(value);

    const dec = userSettings.decimalsymbol || ".";
    const grp = userSettings.numberseparator || ",";
    const parts = value.toFixed(2).split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, grp);
    return parts.join(dec);
};

const getLookupId = (lookup: unknown): string => {
    if (!lookup) return "";
    if (typeof lookup === "string") return lookup.replace(/[{}]/g, "").toLowerCase();

    if (typeof lookup === "object" && lookup !== null) {
        const v = lookup as Record<string, unknown>;
        const id =
            (typeof v.id === "string" && v.id) ||
            (typeof v.value === "string" && v.value) ||
            (typeof v.entityId === "string" && v.entityId) ||
            "";
        return id.replace(/[{}]/g, "").toLowerCase();
    }

    return "";
};

const safeText = (value: unknown): string => {
    if (value === null || value === undefined) return "-";
    const str = String(value).trim();
    return str.length ? str : "-";
};

const toHeader = (key: string): string =>
    key
        .replace(/^vafe_/, "")
        .replace(/^_/, "")
        .replace(/_/g, " ")
        .replace(/\b\w/g, (m) => m.toUpperCase());

const formatCell = (key: string, value: unknown, userSettings: any): string => {
    if (value === null || value === undefined || value === "") return "-";

    const lk = key.toLowerCase();
    if (lk.includes("date") || lk.includes("time") || lk.includes("timestamp")) {
        const d = new Date(String(value));
        if (!Number.isNaN(d.getTime())) return formatDate(value, userSettings);
    }

    if (typeof value === "number") return formatNumber(value, userSettings);

    if (typeof value === "object") {
        try {
            return JSON.stringify(value);
        } catch {
            return String(value);
        }
    }

    return safeText(value);
};

const SummaryStats = ({
    extractions,
}: {
    extractions: ExtractionRow[];
}) => {
    const total = extractions.length;
    const successful = extractions.filter(
        (r) => String(r.vafe_extractionstatus || "").toLowerCase() === "success"
    ).length;

    return (
        <div
            style={{
                display: "flex",
                flexDirection: "row",
                gap: "2rem",
                marginBottom: "1.5rem",
                flexWrap: "wrap",
            }}
            aria-label={t("stats")}
        >
            <div
                style={{
                    background: "#F3F2F1",
                    borderRadius: "8px",
                    padding: "1.25rem 2rem",
                    minWidth: "220px",
                    boxShadow: "0 1px 4px rgba(0,0,0,0.04)",
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                }}
            >
                <Text size={700} weight="bold" as="span">
                    {total}
                </Text>
                <Text size={300} as="span" style={{ color: "#605E5C" }}>
                    {t("totalExtractions")}
                </Text>
            </div>

            <div
                style={{
                    background: "#F3F2F1",
                    borderRadius: "8px",
                    padding: "1.25rem 2rem",
                    minWidth: "220px",
                    boxShadow: "0 1px 4px rgba(0,0,0,0.04)",
                    display: "flex",
                    flexDirection: "column",
                    alignItems: "center",
                }}
            >
                <Text size={700} weight="bold" as="span">
                    {successful}
                </Text>
                <Text size={300} as="span" style={{ color: "#605E5C" }}>
                    {t("successExtractions")}
                </Text>
            </div>
        </div>
    );
};

const ExtractionGrid = ({
    extractionRows,
    writeByFormSubmission,
    userSettings,
    filterText,
    setFilterText,
    onReset,
    onRefresh,
}: {
    extractionRows: ExtractionRow[];
    writeByFormSubmission: Record<string, WriteEventRow>;
    userSettings: any;
    filterText: string;
    setFilterText: (v: string) => void;
    onReset: () => void;
    onRefresh: () => void;
}) => {
    const rows = useMemo(() => {
        return extractionRows.map((r) => {
            const formSubmissionId = getLookupId(r.vafe_formsubmissionid);
            const write = writeByFormSubmission[formSubmissionId];

            return {
                ...r,
                _formSubmissionId: formSubmissionId || "-",
                _d365Status: safeText(write?.vafe_d365status),
                _d365RecordId: safeText(write?.vafe_d365recordid),
                _retryCount: Number(write?.vafe_retrycount ?? 0),
                _rowId: safeText(r.vafe_extractionresultid || r.name || formSubmissionId),
            };
        });
    }, [extractionRows, writeByFormSubmission]);

    const dynamicFieldKeys = useMemo(() => {
        const fixed = new Set([
            "vafe_extractionresultid",
            "name",
            "vafe_formsubmissionid",
            "vafe_extractionstatus",
            "vafe_overallconfidence",
            "vafe_modelversion",
            "vafe_extractiontimestamp",
            "vafe_errormessage",
            "_formSubmissionId",
            "_d365Status",
            "_d365RecordId",
            "_retryCount",
            "_rowId",
        ]);

        const keys = new Set<string>();
        for (const row of rows) {
            Object.keys(row).forEach((k) => {
                if (!fixed.has(k)) keys.add(k);
            });
        }

        return Array.from(keys).sort((a, b) => a.localeCompare(b));
    }, [rows]);

    const filtered = useMemo(() => {
        if (!filterText) return rows;
        const s = filterText.toLowerCase();

        return rows.filter((r) =>
            Object.values(r)
                .map((x) => {
                    if (x === null || x === undefined) return "";
                    if (typeof x === "object") {
                        try {
                            return JSON.stringify(x).toLowerCase();
                        } catch {
                            return String(x).toLowerCase();
                        }
                    }
                    return String(x).toLowerCase();
                })
                .some((x) => x.includes(s))
        );
    }, [rows, filterText]);

    const columns = useMemo(
        () => [
            createTableColumn<typeof filtered[number]>({
                columnId: "vafe_extractionresultid",
                renderHeaderCell: () => t("extractionId"),
                renderCell: (item) => <TableCellLayout>{safeText(item.vafe_extractionresultid)}</TableCellLayout>,
            }),
            createTableColumn<typeof filtered[number]>({
                columnId: "_formSubmissionId",
                renderHeaderCell: () => t("formSubmissionId"),
                renderCell: (item) => <TableCellLayout>{safeText(item._formSubmissionId)}</TableCellLayout>,
            }),
            createTableColumn<typeof filtered[number]>({
                columnId: "vafe_extractionstatus",
                renderHeaderCell: () => t("extractionStatus"),
                renderCell: (item) => <TableCellLayout>{safeText(item.vafe_extractionstatus)}</TableCellLayout>,
            }),
            createTableColumn<typeof filtered[number]>({
                columnId: "vafe_overallconfidence",
                renderHeaderCell: () => t("overallConfidence"),
                renderCell: (item) => (
                    <TableCellLayout>
                        {typeof item.vafe_overallconfidence === "number"
                            ? formatNumber(item.vafe_overallconfidence as number, userSettings)
                            : "-"}
                    </TableCellLayout>
                ),
            }),
            createTableColumn<typeof filtered[number]>({
                columnId: "vafe_modelversion",
                renderHeaderCell: () => t("modelVersion"),
                renderCell: (item) => <TableCellLayout>{safeText(item.vafe_modelversion)}</TableCellLayout>,
            }),
            createTableColumn<typeof filtered[number]>({
                columnId: "vafe_extractiontimestamp",
                renderHeaderCell: () => t("extractionTimestamp"),
                renderCell: (item) => (
                    <TableCellLayout>{formatDate(item.vafe_extractiontimestamp, userSettings)}</TableCellLayout>
                ),
            }),
            createTableColumn<typeof filtered[number]>({
                columnId: "_d365Status",
                renderHeaderCell: () => t("d365Status"),
                renderCell: (item) => <TableCellLayout>{safeText(item._d365Status)}</TableCellLayout>,
            }),
            createTableColumn<typeof filtered[number]>({
                columnId: "_d365RecordId",
                renderHeaderCell: () => t("d365RecordId"),
                renderCell: (item) => <TableCellLayout>{safeText(item._d365RecordId)}</TableCellLayout>,
            }),
            createTableColumn<typeof filtered[number]>({
                columnId: "_retryCount",
                renderHeaderCell: () => t("retryCount"),
                renderCell: (item) => <TableCellLayout>{safeText(item._retryCount)}</TableCellLayout>,
            }),
            createTableColumn<typeof filtered[number]>({
                columnId: "vafe_errormessage",
                renderHeaderCell: () => t("errorMessage"),
                renderCell: (item) => <TableCellLayout truncate>{safeText(item.vafe_errormessage)}</TableCellLayout>,
            }),
            ...dynamicFieldKeys.map((k) =>
                createTableColumn<typeof filtered[number]>({
                    columnId: k,
                    renderHeaderCell: () => toHeader(k),
                    renderCell: (item) => (
                        <TableCellLayout truncate>
                            {formatCell(k, (item as Record<string, unknown>)[k], userSettings)}
                        </TableCellLayout>
                    ),
                })
            ),
        ],
        [filtered, dynamicFieldKeys, userSettings]
    );

    return (
        <div style={{ flex: 1, display: "flex", flexDirection: "column", minHeight: 0 }}>
            <div style={{ display: "flex", alignItems: "center", gap: "1rem", marginBottom: "1rem" }}>
                <Input
                    placeholder={t("searchPlaceholder")}
                    value={filterText}
                    onChange={(e, d) => setFilterText(d.value)}
                    style={{ maxWidth: 360 }}
                    aria-label={t("searchPlaceholder")}
                />
                <Button appearance="secondary" onClick={onReset} disabled={!filterText}>
                    {t("reset")}
                </Button>
                <Button appearance="primary" onClick={onRefresh}>
                    {t("refresh")}
                </Button>
            </div>

            <div style={{ flex: 1, minHeight: 0, maxHeight: "calc(100vh - 260px)", overflow: "auto" }}>
                <DataGrid
                    items={filtered}
                    columns={columns}
                    getRowId={(item) => item._rowId}
                    focusMode="composite"
                    selectionMode="none"
                    style={{ minWidth: 1600 }}
                    aria-label={t("records")}
                >
                    <DataGridHeader>
                        <DataGridRow>
                            {({ renderHeaderCell }) => (
                                <DataGridHeaderCell>{renderHeaderCell()}</DataGridHeaderCell>
                            )}
                        </DataGridRow>
                    </DataGridHeader>
                    <DataGridBody<typeof filtered[number]>>
                        {({ item }) => (
                            <DataGridRow key={item._rowId}>
                                {({ renderCell }) => <DataGridCell>{renderCell(item)}</DataGridCell>}
                            </DataGridRow>
                        )}
                    </DataGridBody>
                </DataGrid>

                {filtered.length === 0 && (
                    <Text size={300} style={{ marginTop: "1rem", color: "#605E5C" }}>
                        {t("noRecords")}
                    </Text>
                )}
            </div>
        </div>
    );
};

const GeneratedComponent = ({ dataApi }: GeneratedComponentProps) => {
    const isRTL = getIsRTL();
    const userSettings = useUserSettings(dataApi);

    const [extractionRows, setExtractionRows] = useState<ExtractionRow[]>([]);
    const [writeByFormSubmission, setWriteByFormSubmission] = useState<Record<string, WriteEventRow>>({});
    const [filterText, setFilterText] = useState("");

    const loadData = async () => {
        if (!dataApi) return;

        const extractionQuery: QueryTableOptions<vafe_extractionresult> = {
            pageSize: 100,
            orderBy: "vafe_extractiontimestamp desc",
        };

        const writeQuery: QueryTableOptions<vafe_d365writeevent> = {
            select: [
                "vafe_formsubmissionid",
                "vafe_d365status",
                "vafe_d365recordid",
                "vafe_retrycount",
                "vafe_timestampwritten",
                "vafe_errordetails",
            ],
            pageSize: 200,
            orderBy: "vafe_timestampwritten desc",
        };

        const [extractionResult, writeResult] = await Promise.all([
            dataApi.queryTable("vafe_extractionresult", extractionQuery),
            dataApi.queryTable("vafe_d365writeevent", writeQuery),
        ]);

        const byFormSubmission: Record<string, WriteEventRow> = {};
        for (const row of (writeResult.rows as WriteEventRow[])) {
            const key = getLookupId(row.vafe_formsubmissionid);
            if (!key) continue;
            if (!byFormSubmission[key]) {
                byFormSubmission[key] = row;
            }
        }

        setExtractionRows(extractionResult.rows as ExtractionRow[]);
        setWriteByFormSubmission(byFormSubmission);
    };

    useEffect(() => {
        loadData();
    }, [dataApi]);

    return (
        <div
            dir={isRTL ? "rtl" : "ltr"}
            style={{
                direction: isRTL ? "rtl" : "ltr",
                flexGrow: 1,
                alignSelf: "stretch",
                width: "100%",
                height: "100%",
                padding: "2rem",
                boxSizing: "border-box",
                overflow: "hidden",
                display: "flex",
                flexDirection: "column",
                background: "#FAFAFA",
            }}
        >
            <header style={{ marginBottom: "1.5rem" }}>
                <Text as="h1" size={800} weight="semibold" block>
                    {t("pageTitle")}
                </Text>
            </header>

            <SummaryStats extractions={extractionRows} />

            <section style={{ flex: 1, minHeight: 0, display: "flex", flexDirection: "column" }}>
                <ExtractionGrid
                    extractionRows={extractionRows}
                    writeByFormSubmission={writeByFormSubmission}
                    userSettings={userSettings}
                    filterText={filterText}
                    setFilterText={setFilterText}
                    onReset={() => setFilterText("")}
                    onRefresh={loadData}
                />
            </section>
        </div>
    );
};

export default GeneratedComponent;
```
