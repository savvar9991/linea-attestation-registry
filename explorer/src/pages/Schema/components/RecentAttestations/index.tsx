import { t } from "i18next";
import { useRef } from "react";
import useSWR from "swr";

import { DataTable } from "@/components/DataTable";
import { attestationColumnsOption, columns, skeletonAttestations } from "@/constants/columns/attestation";
import { columnsSkeleton } from "@/constants/columns/skeleton";
import { SWRKeys } from "@/interfaces/swr/enum";
import { useNetworkContext } from "@/providers/network-provider/context";
import { APP_ROUTES } from "@/routes/constants";

export const RecentAttestations: React.FC<{ schemaId?: string; portalId?: string }> = ({ schemaId, portalId }) => {
  const {
    sdk,
    network: { chain, network },
  } = useNetworkContext();

  const fetchKey = schemaId
    ? `${SWRKeys.GET_RECENT_ATTESTATION_SCHEMA}/${schemaId}/${chain.id}`
    : portalId
    ? `${SWRKeys.GET_RECENT_ATTESTATION_PORTAL}/${portalId}/${chain.id}`
    : `${SWRKeys.GET_RECENT_ATTESTATION_GLOBAL}/${chain.id}`;

  const fetchFunction = schemaId
    ? () => sdk.attestation.findBy(5, 0, { schema: schemaId }, "attestedDate", "desc")
    : portalId
    ? () => sdk.attestation.findBy(5, 0, { portal: portalId }, "attestedDate", "desc")
    : () => sdk.attestation.findBy(5, 0, {}, "attestedDate", "desc");

  const { data: attestations, isLoading } = useSWR(fetchKey, fetchFunction, {
    shouldRetryOnError: false,
  });

  const columnsSkeletonRef = useRef(columnsSkeleton(columns({ sortByDate: false }), attestationColumnsOption));
  const data = isLoading
    ? { columns: columnsSkeletonRef.current, list: skeletonAttestations(5) }
    : {
        columns: columns({ sortByDate: false, chain, network }),
        list: attestations || [],
      };

  return (
    <div className="flex flex-col gap-6 w-full px-5 md:px-10">
      <p className="text-xl not-italic font-semibold text-text-primary dark:text-whiteDefault">
        {t("attestation.recent")}
      </p>
      <DataTable columns={data.columns} data={data.list} link={APP_ROUTES.ATTESTATION_BY_ID} />
    </div>
  );
};
