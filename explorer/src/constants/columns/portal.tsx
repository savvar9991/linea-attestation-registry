import { ColumnDef } from "@tanstack/react-table";
import { Portal } from "@verax-attestation-registry/verax-sdk";
import { t } from "i18next";
import { Chain } from "viem";

import { TdHandler } from "@/components/DataTable/components/TdHandler";
import { HelperIndicator } from "@/components/HelperIndicator";
import { Link } from "@/components/Link";
import { EMPTY_STRING, ZERO, ZERO_ADDRESS } from "@/constants";
import { ColumnsOptions } from "@/interfaces/components";
import { toPortalById } from "@/routes/constants";
import { getBlockExplorerLink } from "@/utils";
import { cropString } from "@/utils/stringUtils";

export const columns = ({ chain }: { chain: Chain }): ColumnDef<Portal>[] => [
  {
    accessorKey: "name",
    header: () => (
      <div className="flex items-center gap-2.5">
        <HelperIndicator type="portal" />
        {t("portal.list.columns.name")}
      </div>
    ),
    cell: ({ row }) => {
      const name = row.getValue("name") as string;
      const id = row.original.id;

      return (
        <Link to={toPortalById(id)} className="hover:underline" onClick={(e) => e.stopPropagation()}>
          {name}
        </Link>
      );
    },
  },
  {
    accessorKey: "description",
    header: () => t("portal.list.columns.description"),
    cell: ({ row }) => {
      const description = row.getValue("description") as string;
      return <p className="max-w-[300px] overflow-hidden text-ellipsis">{description}</p>;
    },
  },
  {
    accessorKey: "owner",
    header: () => <p>{t("portal.list.columns.owner")}</p>,
    cell: ({ row }) => {
      const address = row.original.ownerAddress;
      const id = row.original.id;

      return (
        <TdHandler
          valueUrl={chain ? `${getBlockExplorerLink(chain)}/${address}` : "#"}
          value={cropString(address)}
          to={toPortalById(id)}
        />
      );
    },
  },
];

export const portalColumnsOption: ColumnsOptions = {
  0: {
    minWidth: 150,
    maxWidth: 200,
    isRandomWidth: true,
  },
  1: {
    minWidth: 200,
    maxWidth: 400,
    isRandomWidth: true,
  },
  2: {
    width: 150,
  },
};

export const skeletonPortals = (count: number) =>
  Array(count)
    .fill(null)
    .map(() => ({
      id: ZERO_ADDRESS,
      name: EMPTY_STRING,
      description: EMPTY_STRING,
      ownerAddress: ZERO_ADDRESS,
      ownerName: EMPTY_STRING,
      modules: [],
      isRevocable: false,
      attestationCounter: ZERO,
    }));
